import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_extractor.dart';
import 'categories.dart';
import 'gemini_api.dart';
import 'thumbnail_from_url.dart';

/// Feature #2, for real.
///
/// One call per saved link, asking for structured JSON so the reply is parsed
/// rather than scraped. The key comes from a git-ignored `.env` and is never
/// compiled into a deployed build — see `docs/06-security-and-privacy.md`.
///
/// A note on what the model is given: a browser cannot fetch a TikTok or
/// Instagram page directly (CORS), so this works from the link itself — its
/// host, its slug, its handle — plus what the model already knows. A URL whose
/// slug reads `5-hidden-cafes-in-kyoto` extracts well; an opaque
/// `/reel/C8xK2p/` may come back with nulls, which is exactly the risk the
/// proposal names and why every field here is optional.
///
/// Nothing here ever invents a result. Every failure path throws, and
/// [SampleExtractor] is reached only by having no key at all, never as a quiet
/// substitute for a call that did not work.
class GeminiExtractor implements AiExtractor {
  GeminiExtractor({
    required String apiKey,
    String? model,
    http.Client? httpClient,
    RetryPolicy retry = const RetryPolicy(),
  })  : _override = _clean(model),
        _client = GeminiClient(
          apiKey: apiKey,
          httpClient: httpClient,
          retry: retry,
        );

  /// A pinned id from `GEMINI_MODEL`, or null to ask the API what it has.
  final String? _override;
  final GeminiClient _client;

  /// Resolved once per session, then reused.
  Future<List<String>>? _candidates;

  /// Models that answered "no such model" this session, so a second link does
  /// not spend an attempt rediscovering that.
  final _retired = <String>{};

  /// Extractions currently running, keyed by URL.
  ///
  /// Two taps on Analyze, or a tap and an Enter press, must not become two
  /// billable calls. The second caller joins the first future instead.
  final _inFlight = <String, Future<ExtractionResult>>{};

  /// How many different models to try before giving up, when the first turns
  /// out to be retired.
  static const maxModelsTried = 3;

  @override
  bool get isLive => true;

  /// Visible for tests and for the doc: what this will actually ask for.
  Future<List<String>> get candidates => _resolveCandidates();

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<ExtractionResult> extract(String url, {ExtractionStage? onStage}) {
    final key = url.trim();
    final existing = _inFlight[key];
    if (existing != null) {
      onStage?.call('Already analysing this link');
      return existing;
    }

    final future = _extract(key, onStage);
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  Future<ExtractionResult> _extract(String url, ExtractionStage? onStage) async {
    onStage?.call('Reading the link');

    // Started before the model call and awaited after it. The thumbnail lookup
    // can reach out to a platform that never answers, and it has nothing to do
    // with the model, so it must not be one more thing waited for in series.
    final thumbnail = PostThumbnails.resolve(url);

    final json = await _generate(url, onStage);

    onStage?.call('Reading the reply');
    return _resultFrom(json, url: url, thumbnailUrl: await thumbnail);
  }

  /// Asks each candidate model in turn until one answers.
  ///
  /// A model that is gone moves us to the next candidate; anything else — a
  /// rejected key, a blocked prompt, an exhausted quota — is final and is
  /// reported as itself. Transient failures never get this far: [GeminiClient]
  /// has already retried them with backoff.
  ///
  /// A pinned `GEMINI_MODEL` is called straight away. Listing the catalogue to
  /// confirm what we were already told would be one more request on every
  /// session for no answer we would act on, so discovery happens only if the
  /// pinned id turns out not to exist.
  Future<Map<String, dynamic>> _generate(
    String url,
    ExtractionStage? onStage,
  ) async {
    final tried = <String>[];
    GeminiApiException? last;

    Future<Map<String, dynamic>?> attempt(String model) async {
      tried.add(model);
      onStage?.call('Asking $model');
      try {
        return await _client.generateContent(
          model: model,
          body: _requestBody(url),
          onRetry: (attempt, of, wait) => onStage?.call(
            'Gemini is busy — retrying in ${_seconds(wait)}s '
            '(attempt $attempt of $of)',
          ),
        );
      } on GeminiApiException catch (e) {
        last = e;
        // Only "no such model" is worth moving on from. Everything else would
        // fail identically against the next model, so stop and report it.
        if (!e.isModelUnavailable) throw ExtractionException(_friendly(e, tried));
        _retired.add(model);
        return null;
      }
    }

    final pinned = _override;
    if (pinned != null && !_retired.contains(pinned)) {
      final answer = await attempt(pinned);
      if (answer != null) return answer;
      onStage?.call('$pinned is unavailable — looking for another model');
    }

    final candidates = (await _resolveCandidates())
        .where((model) => !_retired.contains(model))
        .take(maxModelsTried)
        .toList();

    if (candidates.isEmpty && tried.isEmpty) {
      throw const ExtractionException(
        'No Gemini model on this key can run an extraction. Check that the '
        'Generative Language API is enabled for the key in GEMINI_API_KEY.',
      );
    }

    for (final model in candidates) {
      final answer = await attempt(model);
      if (answer != null) return answer;
    }

    throw ExtractionException(_friendly(last!, tried));
  }

  static String _seconds(Duration wait) =>
      (wait.inMilliseconds / 1000).toStringAsFixed(1);

  /// The candidate models, best first, resolved once per session.
  ///
  /// Only reached when there is no pinned model, or the pinned one turned out
  /// not to exist — a typo in `.env` degrades to something that works rather
  /// than breaking the app.
  Future<List<String>> _resolveCandidates() {
    return _candidates ??= () async {
      List<String> discovered;
      try {
        discovered = GeminiModels.rank(await _client.listModels());
      } on GeminiApiException {
        // Listing failed. Not fatal: the static list is exactly for this.
        discovered = const [];
      }
      return discovered.isEmpty ? GeminiModels.fallback : discovered;
    }();
  }

  Map<String, Object?> _requestBody(String url) => {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '$_instructions\n\nURL: $url'},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
          'responseSchema': _responseSchema,
        },
      };

  /// A response schema, so the reply is JSON of a known shape rather than prose
  /// that has to be guessed at. Written as a plain map because that is what the
  /// REST body wants.
  static final Map<String, Object?> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'title': {
        'type': 'STRING',
        'description': 'A short human title for the post, from the link slug.',
      },
      'creator': {
        'type': 'STRING',
        'nullable': true,
        'description': 'The @handle if the URL contains one.',
      },
      'destination': {
        'type': 'STRING',
        'nullable': true,
        'description': 'The place, as "City, Country". Null if none is evident.',
      },
      'country': {'type': 'STRING', 'nullable': true},
      'category': {'type': 'STRING', 'enum': NookCategories.all},
      'summary': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Two or three sentences about what a traveller finds.',
      },
      'best_time': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Best months to visit, e.g. "March-May".',
      },
      'budget_note': {
        'type': 'STRING',
        'nullable': true,
        'description': 'A rough daily budget, e.g. "~EUR80/day".',
      },
      'latitude': {
        'type': 'NUMBER',
        'nullable': true,
        'description': 'Latitude in decimal degrees, or null if the '
            'destination is missing or too broad to place on a map.',
      },
      'longitude': {
        'type': 'NUMBER',
        'nullable': true,
        'description': 'Longitude in decimal degrees, or null if the '
            'destination is missing or too broad to place on a map.',
      },
    },
    'required': ['title', 'category'],
  };

  static const _instructions = '''
You extract travel metadata from a social media link for a trip-planning app.

You are given only the URL. Read the host, the path slug and any handle in it,
and combine that with what you already know about the place named. Do not invent
a destination that the link gives you no reason to believe in: returning null is
correct and expected when the link is opaque.

Return JSON only, matching the schema.
- destination: "City, Country" when a specific place is evident, otherwise null.
- category: exactly one of the listed values. Use "Other" when unsure.
- summary: 2-3 sentences, written for a traveller deciding whether to keep this.
- best_time and budget_note: only when the destination is known; otherwise null.
- latitude/longitude: the coordinates of the destination, in decimal degrees,
  so it can be pinned on a map. Give them only for a place specific enough to
  have a single point: a city, a town, an island, a landmark. For a whole
  region or country ("Southeast Asia", "Anywhere") return null for both.
''';

  /// Digs the model's JSON out of the response envelope.
  ///
  /// The reply can be well-formed HTTP and still carry no answer: a prompt
  /// blocked by a safety filter, a candidate cut off at the token limit, a part
  /// list with no text in it. Each of those is reported as what it is.
  ExtractionResult _resultFrom(
    Map<String, dynamic> response, {
    required String url,
    required String? thumbnailUrl,
  }) {
    final blockReason = (response['promptFeedback'] as Map?)?['blockReason'];
    if (blockReason != null) {
      throw ExtractionException(
        'Gemini declined to read that link ($blockReason). Enter the details '
        'yourself, or try a different link.',
      );
    }

    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const ExtractionException('Gemini returned no result for that link.');
    }

    final candidate = candidates.first as Map;
    final finish = candidate['finishReason'];
    if (finish is String && finish != 'STOP' && finish != 'MAX_TOKENS') {
      throw ExtractionException('Gemini stopped early ($finish). Try again.');
    }

    final parts = (candidate['content'] as Map?)?['parts'];
    final text = parts is List
        ? parts
            .whereType<Map>()
            .map((part) => part['text'])
            .whereType<String>()
            .join()
        : '';
    if (text.trim().isEmpty) {
      throw const ExtractionException('The extraction came back empty.');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const ExtractionException(
        "The extraction couldn't be read. Try again, or enter the details "
        'yourself.',
      );
    }

    String? string(String key) {
      final value = json[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty || trimmed.toLowerCase() == 'null' ? null : trimmed;
    }

    double? number(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // Coordinates are only useful as a pair, and only inside the real ranges.
    final latitude = number('latitude');
    final longitude = number('longitude');
    final placeable = latitude != null &&
        longitude != null &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180 &&
        !(latitude == 0 && longitude == 0);

    return ExtractionResult(
      title: string('title') ?? _titleFromUrl(url),
      creator: string('creator'),
      destination: string('destination'),
      country: string('country'),
      category: NookCategories.normalise(string('category')),
      summary: string('summary'),
      bestTime: string('best_time'),
      budgetNote: string('budget_note'),
      latitude: placeable ? latitude : null,
      longitude: placeable ? longitude : null,
      // Worked out from the link itself rather than asked of the model: a
      // language model cannot know a thumbnail URL, and would invent one.
      // Already in flight since before the model call.
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Turns an API failure into something worth reading, and — where the user
  /// can do something about it — says what.
  String _friendly(GeminiApiException e, List<String> tried) {
    if (e.isAuthFailure) {
      return 'That Gemini API key was rejected (${e.reason ?? e.status}). '
          'Check GEMINI_API_KEY in your .env, and that the Generative Language '
          'API is enabled for it.';
    }
    if (e.status == 429 || e.code == 'RESOURCE_EXHAUSTED') {
      return "You've hit the rate limit on this Gemini key. It resets on its "
          'own — wait a minute and retry, or enter the details yourself.';
    }
    if (e.isModelUnavailable) {
      return 'None of the models this key can reach accepted the request '
          '(tried ${tried.join(', ')}). Set GEMINI_MODEL in .env to one your '
          'key supports.';
    }
    if (e.isTransient) {
      final what = e.status == null
          ? 'Gemini could not be reached'
          : 'Gemini is overloaded (HTTP ${e.status})';
      return '$what. Nook retried this a few times with a growing wait and it '
          'stayed unavailable. This is on their side and usually clears in a '
          'few minutes — retry, or enter the details yourself.';
    }
    return 'Extraction failed: ${e.message}';
  }

  /// Last resort so a post is never saved with an empty title.
  static String _titleFromUrl(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const [];
    for (final segment in segments.reversed) {
      if (segment.contains('-')) {
        return segment
            .split('-')
            .where((word) => word.isNotEmpty)
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
      }
    }
    return 'Saved link';
  }
}
