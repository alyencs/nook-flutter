// The Gemini REST API, spoken directly.
//
// This replaces `google_generative_ai`, and the reason is narrow and concrete:
// that package discards the HTTP status code. Its client raises
//
//     if (response.statusCode >= 500) {
//       throw GenerativeAIException('Server Error [$statusCode]: ${body}');
//     }
//
// so a 503 arrives as prose with the number buried in it, and a 429 does not
// even take that branch — it is decoded as a normal body and turned into a
// `ServerException` carrying nothing but a message. Deciding whether a failure
// is worth retrying is a decision about the status code, and through that
// package the only way to make it is to scrape a string. Talking to the
// endpoint directly costs about a hundred lines and gives back the status, the
// `error.status` code, the `details[].reason`, and the `Retry-After` header.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// One failure from the API, with everything needed to decide what to do next.
class GeminiApiException implements Exception {
  const GeminiApiException({
    required this.message,
    this.status,
    this.code,
    this.reason,
    this.retryAfter,
  });

  /// The human-readable `error.message`, or a transport failure description.
  final String message;

  /// The HTTP status. Null when the request never reached a response at all —
  /// DNS failure, connection reset, timeout.
  final int? status;

  /// `error.status`: `UNAVAILABLE`, `RESOURCE_EXHAUSTED`, `NOT_FOUND`, ...
  final String? code;

  /// `error.details[].reason`: `API_KEY_INVALID`, `SERVICE_DISABLED`, ...
  final String? reason;

  /// The server's own `Retry-After`, when it sent one. Honoured over the
  /// computed backoff, because the server knows when it will be ready and we
  /// are guessing.
  final Duration? retryAfter;

  /// Whether trying the same request again could plausibly succeed.
  ///
  /// 429 and the 5xx family are the API saying "not now" rather than "not
  /// ever", and a null status means the request never landed, which is the most
  /// retryable case of all.
  bool get isTransient {
    if (status == null) return true;
    return const {408, 425, 429, 500, 502, 503, 504}.contains(status);
  }

  /// Whether this particular model is gone, so the next candidate should be
  /// tried instead of retrying this one.
  ///
  /// A retired model answers `404 NOT_FOUND` with "is not found for API version
  /// v1beta, or is not supported for generateContent".
  bool get isModelUnavailable {
    if (status == 404) return true;
    if (status != 400) return false;
    final lower = message.toLowerCase();
    return lower.contains('not found') || lower.contains('not supported');
  }

  /// Whether the key itself is the problem, which no amount of retrying fixes.
  bool get isAuthFailure {
    if (status == 401 || status == 403) return true;
    if (reason == 'API_KEY_INVALID' || reason == 'SERVICE_DISABLED') return true;
    return status == 400 && message.toLowerCase().contains('api key');
  }

  @override
  String toString() =>
      'GeminiApiException(${status ?? 'no response'} ${code ?? ''}): $message';
}

/// How many times to try, and how long to wait between.
///
/// Exponential with equal jitter: the delay doubles, and half of each one is
/// randomised so that several clients retrying together do not synchronise into
/// a second spike. [deadline] bounds the whole sequence, so a request cannot
/// keep the screen busy indefinitely no matter how the individual attempts go.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 4,
    this.baseDelay = const Duration(milliseconds: 600),
    this.maxDelay = const Duration(seconds: 8),
    this.attemptTimeout = const Duration(seconds: 20),
    this.deadline = const Duration(seconds: 45),
  }) : assert(maxAttempts >= 1);

  /// Total tries, not retries: 4 means one call and three more.
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Cap on a single HTTP call, so one hung socket cannot eat the deadline.
  final Duration attemptTimeout;

  /// Cap on the whole sequence, waits included.
  final Duration deadline;

  /// The wait before attempt [attempt], counting the first attempt as 1.
  Duration delayBefore(int attempt, Random random) {
    final exponential = baseDelay * pow(2, attempt - 2).toDouble();
    final capped = exponential > maxDelay ? maxDelay : exponential;
    final half = capped ~/ 2;
    return half + Duration(microseconds: random.nextInt(half.inMicroseconds + 1));
  }
}

/// Reports a retry so the screen can say what is happening rather than showing
/// the same spinner for twenty seconds.
typedef RetryNotice = void Function(int attempt, int maxAttempts, Duration wait);

/// A thin client over `generativelanguage.googleapis.com`.
class GeminiClient {
  GeminiClient({
    required String apiKey,
    http.Client? httpClient,
    this.retry = const RetryPolicy(),
    Random? random,
  })  : _apiKey = apiKey,
        _http = httpClient ?? http.Client(),
        _random = random ?? Random();

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  final String _apiKey;
  final http.Client _http;
  final RetryPolicy retry;
  final Random _random;

  /// The model ids this key can actually call `generateContent` on.
  ///
  /// Asking beats hardcoding. Google retires model ids on a published schedule
  /// — `gemini-2.0-flash` was shut down on 1 June 2026, which is what broke
  /// this app — so any id compiled in today is a future outage. This asks the
  /// API what exists now.
  Future<List<String>> listModels() async {
    final json = await _send('GET', 'models?pageSize=200');
    final models = json['models'];
    if (models is! List) return const [];

    final ids = <String>[];
    for (final entry in models) {
      if (entry is! Map) continue;
      final name = entry['name'];
      final methods = entry['supportedGenerationMethods'];
      if (name is! String) continue;
      if (methods is! List || !methods.contains('generateContent')) continue;
      ids.add(name.startsWith('models/') ? name.substring(7) : name);
    }
    return ids;
  }

  /// One structured-output generation, retried on transient failures.
  Future<Map<String, dynamic>> generateContent({
    required String model,
    required Map<String, Object?> body,
    RetryNotice? onRetry,
  }) {
    return _send(
      'POST',
      'models/$model:generateContent',
      body: body,
      onRetry: onRetry,
    );
  }

  void close() => _http.close();

  /// The retry loop. Every request in this file goes through it.
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    RetryNotice? onRetry,
  }) async {
    final started = DateTime.now();
    final uri = Uri.parse('$_base/$path');
    GeminiApiException? last;

    for (var attempt = 1; attempt <= retry.maxAttempts; attempt++) {
      if (attempt > 1) {
        final wait = _waitBefore(attempt, last, started);
        // Null means the wait would outrun the deadline: stop now with the real
        // error rather than sleeping into a timeout the user has to sit through.
        if (wait == null) break;
        onRetry?.call(attempt, retry.maxAttempts, wait);
        await Future<void>.delayed(wait);
      }

      try {
        return await _once(method, uri, body);
      } on GeminiApiException catch (e) {
        last = e;
        // A dead model, a rejected key or a malformed request will fail exactly
        // the same way next time. Only "not now" earns another attempt.
        if (!e.isTransient) rethrow;
        if (DateTime.now().difference(started) >= retry.deadline) break;
      }
    }

    throw last ??
        const GeminiApiException(message: 'The request could not be sent.');
  }

  /// The wait before [attempt], or null if there is no time left for it.
  Duration? _waitBefore(
    int attempt,
    GeminiApiException? last,
    DateTime started,
  ) {
    final computed = retry.delayBefore(attempt, _random);
    // A server that says how long to wait is telling us something we cannot
    // work out ourselves, so it wins over the computed backoff.
    final asked = last?.retryAfter;
    final wait = (asked != null && asked > computed) ? asked : computed;

    final remaining = retry.deadline - DateTime.now().difference(started);
    return wait >= remaining ? null : wait;
  }

  /// A single HTTP round trip, with every failure shaped into one exception.
  Future<Map<String, dynamic>> _once(
    String method,
    Uri uri,
    Map<String, Object?>? body,
  ) async {
    final headers = {
      'x-goog-api-key': _apiKey,
      'content-type': 'application/json',
    };

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(retry.attemptTimeout);
      response = await http.Response.fromStream(streamed)
          .timeout(retry.attemptTimeout);
    } on TimeoutException {
      throw GeminiApiException(
        message: 'Gemini did not answer within '
            '${retry.attemptTimeout.inSeconds} seconds.',
      );
    } catch (e) {
      // No status: the request never reached a server. Retryable by definition.
      throw GeminiApiException(message: 'Could not reach Gemini: $e');
    }

    if (response.statusCode == 200) {
      try {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } catch (_) {
        // A 200 that is not JSON is not a server outage — retrying will not
        // turn it into JSON — so it is raised as a terminal 200.
        throw const GeminiApiException(
          status: 200,
          message: 'Gemini returned a reply that could not be read as JSON.',
        );
      }
    }

    throw _errorFrom(response);
  }

  /// Unpacks Google's error envelope, keeping the parts that decide behaviour.
  ///
  /// ```json
  /// {"error": {"code": 503, "message": "...", "status": "UNAVAILABLE",
  ///            "details": [{"reason": "API_KEY_INVALID"}]}}
  /// ```
  GeminiApiException _errorFrom(http.Response response) {
    String message = 'Gemini returned HTTP ${response.statusCode}.';
    String? code;
    String? reason;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final error = decoded is Map ? decoded['error'] : null;
      if (error is Map) {
        if (error['message'] is String) message = error['message'] as String;
        if (error['status'] is String) code = error['status'] as String;
        final details = error['details'];
        if (details is List) {
          for (final detail in details) {
            if (detail is Map && detail['reason'] is String) {
              reason = detail['reason'] as String;
              break;
            }
          }
        }
      }
    } catch (_) {
      // A non-JSON error body — an HTML proxy page, say. The status still
      // carries the meaning, so keep the default message and go on.
    }

    return GeminiApiException(
      message: message,
      status: response.statusCode,
      code: code,
      reason: reason,
      retryAfter: _retryAfter(response.headers['retry-after']),
    );
  }

  /// `Retry-After` is either a count of seconds or an HTTP date.
  static Duration? _retryAfter(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    if (seconds != null) return Duration(seconds: seconds.clamp(0, 300));
    final date = DateTime.tryParse(header.trim());
    if (date == null) return null;
    final wait = date.difference(DateTime.now());
    return wait.isNegative ? Duration.zero : wait;
  }
}

/// Which model to ask, given what the key can reach.
abstract final class GeminiModels {
  /// Used only when the model list cannot be fetched.
  ///
  /// These are the rolling aliases rather than pinned ids on purpose: with no
  /// live information about what exists, an id that Google re-points on every
  /// release is the safer guess than one that can be retired out from under the
  /// app — which is precisely how `gemini-2.0-flash` broke it.
  static const fallback = <String>[
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
  ];

  /// Model families that cannot do this job, or would do it badly.
  ///
  /// Preview and experimental ids come and go without notice, and a thinking
  /// model spends seconds reasoning before it answers — which is what made an
  /// extraction take tens of seconds when this app was on `gemini-2.5-flash`.
  static const _excluded = [
    'embedding', 'aqa', 'imagen', 'image', 'tts', 'audio', 'live', 'vision',
    'learnlm', 'gemma', 'veo', 'robotics', 'computer-use', 'preview',
    'experimental', 'thinking', '-exp',
  ];

  /// The candidates from [available], best first.
  ///
  /// Flash ahead of flash-lite, and pro only as a last resort.
  ///
  /// This used to prefer flash-lite, on the reasoning that the call was tiny —
  /// a URL in, a small JSON object out. It is not tiny any more: the model now
  /// receives the post's real title and description and has to read them,
  /// recognise that "Nakazakicho" is a district of Osaka, and decide what the
  /// source does *not* support. That is comprehension, and it is the job flash
  /// is for. Flash-lite stays next in line, so a key that cannot reach flash
  /// still works.
  ///
  /// Within a family the newest version wins, and a plain id beats a suffixed
  /// one (`gemini-3.1-flash` over `gemini-3.1-flash-001`).
  static List<String> rank(Iterable<String> available) {
    final candidates = available
        .map((id) => id.toLowerCase())
        .where((id) => id.startsWith('gemini'))
        .where((id) => !_excluded.any(id.contains))
        .toSet()
        .toList();

    int family(String id) {
      if (id.contains('flash-lite')) return 2;
      if (id.contains('flash')) return 3;
      if (id.contains('pro')) return 1;
      return 0;
    }

    double version(String id) {
      final match = RegExp(r'gemini-(\d+)(?:\.(\d+))?').firstMatch(id);
      if (match == null) return 0;
      return double.parse('${match.group(1)}.${match.group(2) ?? '0'}');
    }

    candidates.removeWhere((id) => family(id) == 0);
    candidates.sort((a, b) {
      final byFamily = family(b).compareTo(family(a));
      if (byFamily != 0) return byFamily;
      final byVersion = version(b).compareTo(version(a));
      if (byVersion != 0) return byVersion;
      final byLength = a.length.compareTo(b.length);
      return byLength != 0 ? byLength : a.compareTo(b);
    });
    return candidates;
  }
}
