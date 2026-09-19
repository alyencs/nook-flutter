import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_extractor.dart';
import 'categories.dart';
import 'gemini_api.dart';
import 'source_metadata.dart';
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
        _sourceClient = httpClient,
        _client = GeminiClient(
          apiKey: apiKey,
          httpClient: httpClient,
          retry: retry,
        );

  /// A pinned id from `GEMINI_MODEL`, or null to ask the API what it has.
  final String? _override;
  final GeminiClient _client;

  /// Shared with the Gemini client so a test can script both the oEmbed lookup
  /// and the model call through one handler.
  final http.Client? _sourceClient;

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
    onStage?.call('Reading the post');

    // The post itself, before the model sees anything. This is the step that
    // was missing: without it the model received a bare URL and could only
    // answer from an eleven-character video id.
    final source = await SourceMetadataFetcher.fetch(url, client: _sourceClient);
    if (source.hasText) {
      onStage?.call('Read "${_shorten(source.title ?? '')}"');
    }

    // Started before the model call and awaited after it. The thumbnail lookup
    // can reach out to a platform that never answers, and it has nothing to do
    // with the model, so it must not be one more thing waited for in series.
    final thumbnail = PostThumbnails.resolve(url, source: source);

    final json = await _generate(url, source, onStage);

    onStage?.call('Reading the reply');
    return _resultFrom(
      json,
      url: url,
      source: source,
      thumbnailUrl: await thumbnail,
    );
  }

  static String _shorten(String value) =>
      value.length <= 40 ? value : '${value.substring(0, 39)}…';

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
    SourceMetadata source,
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
          body: _requestBody(source),
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

  Map<String, Object?> _requestBody(SourceMetadata source) => {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '$_instructions\n\n--- SOURCE ---\n'
                  '${source.toPromptBlock()}--- END SOURCE ---'},
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
  ///
  /// The location fields step from most specific to least on purpose. Asking
  /// for one "destination" is what produced "Japan": there was nowhere to put a
  /// neighbourhood, so a neighbourhood in the source had nowhere to go.
  static final Map<String, Object?> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'title': {
        'type': 'STRING',
        'description': 'The post\'s real human title or caption, copied from '
            'the source. Never an id, a URL or a filename.',
      },
      'caption': {
        'type': 'STRING',
        'nullable': true,
        'description': 'The post\'s own description or caption text, kept as '
            'written. Null if the source carries none.',
      },
      'creator': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Channel name, display name or page name, as given.',
      },
      'creator_handle': {
        'type': 'STRING',
        'nullable': true,
        'description': 'The @handle, if the source has one.',
      },
      'place_name': {
        'type': 'STRING',
        'nullable': true,
        'description': 'The specific cafe, restaurant, shop, hotel or landmark '
            'the post is about, if it names one.',
      },
      'address': {'type': 'STRING', 'nullable': true},
      'neighbourhood': {
        'type': 'STRING',
        'nullable': true,
        'description': 'District or neighbourhood, e.g. "Nakazakicho".',
      },
      'city': {'type': 'STRING', 'nullable': true},
      'region': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Prefecture, state or province.',
      },
      'country': {'type': 'STRING', 'nullable': true},
      'category': {'type': 'STRING', 'enum': NookCategories.all},
      'summary': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Two or three sentences about what a traveller finds, '
            'drawn only from the source.',
      },
      'best_time': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Only if the source mentions a season, month or date.',
      },
      'budget_note': {
        'type': 'STRING',
        'nullable': true,
        'description': 'Only if the source mentions a price or cost.',
      },
      'latitude': {
        'type': 'NUMBER',
        'nullable': true,
        'description': 'Decimal degrees for the specific place or '
            'neighbourhood. Null unless the location is specific enough to '
            'have a single point.',
      },
      'longitude': {'type': 'NUMBER', 'nullable': true},
    },
    'required': ['title', 'category'],
  };

  static const _instructions = '''
You extract travel metadata from a saved social media post for a trip-planning
app called Nook. Everything you need is in the SOURCE block below.

Work only from what the SOURCE says. It is better to return null than to fill a
field with something plausible. In particular, never invent a place, a business,
an address, a creator, a price, a date, or a pair of coordinates. If the source
does not support a field, that field is null. You will not be penalised for
nulls; you will be wrong if you guess.

- title: the post's real title or caption, copied from TITLE. Never the
  SOURCE_ID, never the URL. Only if there is genuinely no title anywhere may you
  describe the post in a few words instead.
- caption: the post's own description or caption text. On platforms where the
  title *is* the caption, repeat it here only if it carries detail beyond the
  title; otherwise null.
- creator / creator_handle: copy from CREATOR_NAME and CREATOR_HANDLE. Never use
  the SOURCE_ID or any part of the URL as a creator.
- Location: go as specific as the source honestly supports, and no further. If
  the post names a cafe, give place_name. If it names a district, give
  neighbourhood. Fill in city, region and country when they follow from what is
  named. A post that only says "Japan" gets country alone and nulls above it.
- latitude / longitude: only for a place specific enough to have one point — a
  named venue, a neighbourhood, a town. For a whole country or region
  ("Japan", "Southeast Asia") return null for both, even though you know where
  the country is. A pin in the middle of a country is a false precision.
- best_time and budget_note: only when the source actually mentions a season,
  a date, a price or a cost.
- category: exactly one of the listed values. Use "Other" when unsure.

Return JSON only, matching the schema.
''';

  /// Digs the model's JSON out of the response envelope.
  ///
  /// The reply can be well-formed HTTP and still carry no answer: a prompt
  /// blocked by a safety filter, a candidate cut off at the token limit, a part
  /// list with no text in it. Each of those is reported as what it is.
  ExtractionResult _resultFrom(
    Map<String, dynamic> response, {
    required String url,
    required SourceMetadata source,
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

    final placeName = string('place_name');
    final neighbourhood = string('neighbourhood');
    final city = string('city');
    final region = string('region');
    final country = string('country');

    // The source is trusted over the model for anything the source already
    // states outright. A title and a channel name that were read from the
    // platform are facts; the model's version of them is a paraphrase at best.
    final title = source.title ?? string('title') ?? _titleFromUrl(url);
    final creator = source.creator ?? string('creator');

    // A pin needs somewhere specific to point. Country-level coordinates are
    // dropped even when the model returns them, because a marker in the middle
    // of Japan claims a precision the post never had — Travel Details shows the
    // placeholder and says why instead.
    final specific =
        placeName != null || neighbourhood != null || city != null ||
            string('address') != null;

    return ExtractionResult(
      title: title,
      caption: string('caption') ?? source.description,
      creator: creator,
      creatorHandle: string('creator_handle') ?? source.creatorHandle,
      destination: _destinationFrom(
        placeName: placeName,
        neighbourhood: neighbourhood,
        city: city,
        region: region,
        country: country,
      ),
      placeName: placeName,
      address: string('address'),
      neighbourhood: neighbourhood,
      city: city,
      region: region,
      country: country,
      category: NookCategories.normalise(string('category')),
      summary: string('summary'),
      bestTime: string('best_time'),
      budgetNote: string('budget_note'),
      latitude: placeable && specific ? latitude : null,
      longitude: placeable && specific ? longitude : null,
      // Worked out from the link and the source rather than asked of the model:
      // a language model cannot know a thumbnail URL, and would invent one.
      // Already in flight since before the model call.
      thumbnailUrl: thumbnailUrl,
      sourceId: source.sourceId,
      mediaType: source.mediaType,
    );
  }

  /// The one-line location, built from the most specific parts available.
  ///
  /// Two parts at most, so a card reads "Nakazakicho, Osaka" rather than
  /// "Cafe X, Nakazakicho, Osaka, Osaka Prefecture, Japan".
  static String? _destinationFrom({
    String? placeName,
    String? neighbourhood,
    String? city,
    String? region,
    String? country,
  }) {
    final parts = <String>[
      ?placeName,
      ?neighbourhood,
      ?city,
      if (city == null) ?region,
      ?country,
    ];
    if (parts.isEmpty) return null;
    return parts.take(2).join(', ');
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
