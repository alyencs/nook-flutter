// The Anthropic Messages API, spoken directly.
//
// There is no first-party Dart SDK, and the REST surface is small enough that
// one does not buy much. What this file does buy is the HTTP status code:
// deciding whether a failure is worth retrying is a decision about the status,
// and a wrapper that folds everything into one exception type takes that away.
// Talking to the endpoint directly gives back the status, the `error.type`, and
// the `retry-after` header.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// One failure from the API, with everything needed to decide what to do next.
class ClaudeApiException implements Exception {
  const ClaudeApiException({
    required this.message,
    this.status,
    this.type,
    this.retryAfter,
  });

  /// The human-readable `error.message`, or a transport failure description.
  final String message;

  /// The HTTP status. Null when the request never reached a response at all —
  /// DNS failure, connection reset, timeout.
  final int? status;

  /// `error.type`: `authentication_error`, `rate_limit_error`,
  /// `overloaded_error`, `not_found_error`, `invalid_request_error`, ...
  final String? type;

  /// The server's own `retry-after`, when it sent one. Honoured over the
  /// computed backoff, because the server knows when it will be ready and we
  /// are guessing.
  final Duration? retryAfter;

  /// Whether trying the same request again could plausibly succeed.
  ///
  /// 429, the 5xx family and 529 are the API saying "not now" rather than "not
  /// ever", and a null status means the request never landed, which is the most
  /// retryable case of all.
  bool get isTransient {
    if (status == null) return true;
    return const {408, 409, 429, 500, 502, 503, 504, 529}.contains(status);
  }

  /// Whether the service is busy, as opposed to something wrong with the
  /// request, the key or the network.
  ///
  /// 529 is Anthropic's own "overloaded" status and is the usual shape of this.
  bool get isOverloaded {
    if (type == 'overloaded_error') return true;
    return const {500, 502, 503, 504, 529}.contains(status);
  }

  /// Whether this particular model id is gone or not available to this key, so
  /// the next candidate should be tried instead of retrying this one.
  bool get isModelUnavailable {
    if (status == 404 || type == 'not_found_error') return true;
    if (status != 400) return false;
    final lower = message.toLowerCase();
    return lower.contains('model') &&
        (lower.contains('not found') ||
            lower.contains('not supported') ||
            lower.contains('does not exist'));
  }

  /// Whether the key itself is the problem, which no amount of retrying fixes.
  bool get isAuthFailure {
    if (status == 401 || status == 403) return true;
    if (type == 'authentication_error' || type == 'permission_error') {
      return true;
    }
    return status == 400 && message.toLowerCase().contains('api key');
  }

  /// Whether the account is out of credit. Distinct from a rate limit: waiting
  /// does not fix it, so it is reported rather than retried.
  bool get isBillingFailure =>
      type == 'billing_error' ||
      (status == 400 && message.toLowerCase().contains('credit balance'));

  @override
  String toString() =>
      'ClaudeApiException(${status ?? 'no response'} ${type ?? ''}): $message';
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
    return half +
        Duration(microseconds: random.nextInt(half.inMicroseconds + 1));
  }
}

/// Reports a retry so the screen can say what is happening rather than showing
/// the same spinner for twenty seconds.
typedef RetryNotice =
    void Function(int attempt, int maxAttempts, Duration wait);

/// A thin client over `api.anthropic.com`.
class ClaudeClient {
  ClaudeClient({
    required String apiKey,
    http.Client? httpClient,
    this.retry = const RetryPolicy(),
    Random? random,
  }) : _apiKey = apiKey,
       _http = httpClient ?? http.Client(),
       _random = random ?? Random();

  static const _base = 'https://api.anthropic.com/v1';

  /// The API version this client is written against. Anthropic keeps old
  /// versions working, so pinning one means a server-side change cannot alter
  /// the response shape under a build that is already deployed.
  static const apiVersion = '2023-06-01';

  final String _apiKey;
  final http.Client _http;
  final RetryPolicy retry;
  final Random _random;

  /// One message, retried on transient failures.
  Future<Map<String, dynamic>> createMessage({
    required Map<String, Object?> body,
    RetryNotice? onRetry,
  }) {
    return _send('messages', body: body, onRetry: onRetry);
  }

  void close() => _http.close();

  /// The retry loop. Every request in this file goes through it.
  Future<Map<String, dynamic>> _send(
    String path, {
    required Map<String, Object?> body,
    RetryNotice? onRetry,
  }) async {
    final started = DateTime.now();
    final uri = Uri.parse('$_base/$path');
    ClaudeApiException? last;

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
        return await _once(uri, body);
      } on ClaudeApiException catch (e) {
        last = e;
        // A dead model, a rejected key or a malformed request will fail exactly
        // the same way next time. Only "not now" earns another attempt.
        if (!e.isTransient) rethrow;
        if (DateTime.now().difference(started) >= retry.deadline) break;
      }
    }

    throw last ??
        const ClaudeApiException(message: 'The request could not be sent.');
  }

  /// The wait before [attempt], or null if there is no time left for it.
  Duration? _waitBefore(
    int attempt,
    ClaudeApiException? last,
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
    Uri uri,
    Map<String, Object?> body,
  ) async {
    final headers = {
      'x-api-key': _apiKey,
      'anthropic-version': apiVersion,
      'content-type': 'application/json',
      // Without this the browser's preflight is refused and the call never
      // leaves the page. It is also the header that names what this build is
      // doing: calling the API straight from the client, with the key that is
      // in the bundle. See docs/06-security-and-privacy.md for why that is
      // acceptable for a local build and never for a deployed one.
      if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
    };

    http.Response response;
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(retry.attemptTimeout);
      response = await http.Response.fromStream(
        streamed,
      ).timeout(retry.attemptTimeout);
    } on TimeoutException {
      throw ClaudeApiException(
        message:
            'The AI service did not answer within '
            '${retry.attemptTimeout.inSeconds} seconds.',
      );
    } catch (e) {
      // No status: the request never reached a server. Retryable by definition.
      throw ClaudeApiException(
        message: 'Could not reach the AI service: $e',
      );
    }

    if (response.statusCode == 200) {
      try {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } catch (_) {
        // A 200 that is not JSON is not a server outage — retrying will not
        // turn it into JSON — so it is raised as a terminal 200.
        throw const ClaudeApiException(
          status: 200,
          message: 'The AI service returned a reply that could not be read.',
        );
      }
    }

    throw _errorFrom(response);
  }

  /// Unpacks Anthropic's error envelope, keeping the parts that decide
  /// behaviour.
  ///
  /// ```json
  /// {"type": "error",
  ///  "error": {"type": "rate_limit_error", "message": "..."}}
  /// ```
  ClaudeApiException _errorFrom(http.Response response) {
    String message = 'The AI service returned HTTP ${response.statusCode}.';
    String? type;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final error = decoded is Map ? decoded['error'] : null;
      if (error is Map) {
        if (error['message'] is String) message = error['message'] as String;
        if (error['type'] is String) type = error['type'] as String;
      }
    } catch (_) {
      // A non-JSON error body — an HTML proxy page, say. The status still
      // carries the meaning, so keep the default message and go on.
    }

    return ClaudeApiException(
      message: message,
      status: response.statusCode,
      type: type,
      retryAfter: _retryAfter(response.headers['retry-after']),
    );
  }

  /// `retry-after` is either a count of seconds or an HTTP date.
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

/// Which model to ask.
abstract final class ClaudeModels {
  /// The model Nook runs on: the fast, inexpensive tier, which is the right
  /// shape for both jobs here — schema-constrained extraction from text that is
  /// already in the prompt, and a short structured plan.
  ///
  /// A dated id rather than the rolling alias, so a new release cannot change
  /// the behaviour of a build that is already out.
  static const haiku = 'claude-haiku-4-5-20251001';

  /// Tried in order when the pinned id is refused.
  ///
  /// The alias is the second entry on purpose: if the dated id is ever retired,
  /// the alias still resolves to a working Haiku, and the app degrades to "a
  /// slightly different model" rather than to no AI at all.
  static const fallback = <String>[haiku, 'claude-haiku-4-5'];

  /// The candidates to try for a session, best first, given an optional pinned
  /// id from `CLAUDE_MODEL`.
  static List<String> candidates(String? pinned) {
    final trimmed = pinned?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return [trimmed, ...fallback.where((id) => id != trimmed)];
  }
}

/// Builds the request body for one structured-output call.
///
/// Anthropic has no `responseSchema`. The equivalent is a tool the model is
/// forced to call: `tool_choice` names it, `input_schema` describes it, and the
/// reply arrives as a `tool_use` block whose `input` is already a decoded map of
/// that shape. That is strictly better than asking for JSON in prose and
/// decoding the text: there is no code fence to strip and no half-written
/// object to fail a parse on.
Map<String, Object?> claudeToolRequest({
  required String model,
  required String system,
  required String prompt,
  required String toolName,
  required String toolDescription,
  required Map<String, Object?> schema,
  required int maxTokens,
  double? temperature,
}) => {
  'model': model,
  'max_tokens': maxTokens,
  'temperature': ?temperature,
  'system': system,
  'messages': [
    {'role': 'user', 'content': prompt},
  ],
  'tools': [
    {
      'name': toolName,
      'description': toolDescription,
      'input_schema': schema,
    },
  ],
  // Forced, not offered: the model has exactly one thing it may do with this
  // request, so there is no path where it answers in prose instead.
  'tool_choice': {'type': 'tool', 'name': toolName},
};

/// The decoded arguments of the forced tool call, or null if the reply carried
/// none.
///
/// A reply can be well-formed HTTP and still have no answer in it: a refusal, a
/// message cut off at `max_tokens` before the tool block was finished, or a
/// content list with nothing of this shape in it. Each is a different message to
/// the user, so this returns null and lets the caller read [stopReasonOf].
Map<String, dynamic>? claudeToolInput(
  Map<String, dynamic> response,
  String toolName,
) {
  final content = response['content'];
  if (content is! List) return null;

  for (final block in content) {
    if (block is! Map) continue;
    if (block['type'] != 'tool_use') continue;
    if (block['name'] != toolName) continue;
    final input = block['input'];
    if (input is Map<String, dynamic>) return input;
    if (input is Map) return Map<String, dynamic>.from(input);
  }
  return null;
}

/// `stop_reason`: `end_turn`, `tool_use`, `max_tokens`, `stop_sequence`,
/// `refusal`.
String? stopReasonOf(Map<String, dynamic> response) {
  final reason = response['stop_reason'];
  return reason is String ? reason : null;
}
