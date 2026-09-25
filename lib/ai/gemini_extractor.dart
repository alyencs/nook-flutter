import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_extractor.dart';
import 'categories.dart';
import 'gemini_api.dart';
import 'post_place.dart';
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
    String? youTubeApiKey,
    String? facebookToken,
    http.Client? httpClient,
    RetryPolicy retry = const RetryPolicy(),
  }) : _override = _clean(model),
       _youTubeApiKey = _clean(youTubeApiKey),
       _facebookToken = _clean(facebookToken),
       _sourceClient = httpClient,
       _client = GeminiClient(
         apiKey: apiKey,
         httpClient: httpClient,
         retry: retry,
       );

  /// A pinned id from `GEMINI_MODEL`, or null to ask the API what it has.
  final String? _override;
  final String? _youTubeApiKey;

  /// `APP_ID|CLIENT_TOKEN` for Meta's Graph API, which is the only way to read
  /// an Instagram or Facebook post's text since their public oEmbed was
  /// withdrawn. Optional: without it those two extract from the URL alone, and
  /// the prompt says so rather than letting the model fill the gap.
  final String? _facebookToken;
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
      onStage?.call(ExtractionPhase.analysing);
      return existing;
    }

    final future = _extract(key, onStage);
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  Future<ExtractionResult> _extract(
    String url,
    ExtractionStage? onStage,
  ) async {
    onStage?.call(ExtractionPhase.readingPost);

    // The post itself, before the model sees anything. This is the step that
    // was missing: without it the model received a bare URL and could only
    // answer from an eleven-character video id.
    final source = await SourceMetadataFetcher.fetch(
      url,
      client: _sourceClient,
      youTubeApiKey: _youTubeApiKey,
      facebookToken: _facebookToken,
    );

    // Started before the model call and awaited after it. The thumbnail lookup
    // can reach out to a platform that never answers, and it has nothing to do
    // with the model, so it must not be one more thing waited for in series.
    final thumbnail = PostThumbnails.resolve(url, source: source);

    final json = await _generate(url, source, onStage);

    onStage?.call(ExtractionPhase.finishing);
    return _resultFrom(
      json,
      url: url,
      source: source,
      thumbnailUrl: await thumbnail,
    );
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
    SourceMetadata source,
    ExtractionStage? onStage,
  ) async {
    final tried = <String>[];
    GeminiApiException? last;

    Future<Map<String, dynamic>?> attempt(String model) async {
      tried.add(model);
      onStage?.call(ExtractionPhase.analysing);
      try {
        return await _client.generateContent(
          model: model,
          body: _requestBody(source),
          // Still one phase from the outside. A retry is part of the wait, not
          // a separate thing worth narrating.
          onRetry: (attempt, of, wait) =>
              onStage?.call(ExtractionPhase.analysing),
        );
      } on GeminiApiException catch (e) {
        last = e;

        // A model that no longer exists is gone for this session.
        if (e.isModelUnavailable) {
          _retired.add(model);
          return null;
        }

        // This is the fix for the 503s. An overloaded model means *that
        // model's* capacity right now, and the client has already retried it
        // with backoff. Retrying it further is waiting on the same queue;
        // another model is a different pool and usually answers immediately.
        // Not retired, because it will be fine again shortly.
        //
        // Narrower than `isTransient` on purpose: a 429 is the key's quota and
        // a null status never reached a server, so neither is worth trying a
        // second model for — that would turn one failure into five.
        if (e.isModelOverloaded) return null;

        // A rejected key, a blocked prompt, an exhausted quota: these fail
        // identically against every model, so stop rather than work through
        // the list producing the same error four times.
        throw ExtractionException(_friendly(e, tried));
      }
    }

    final pinned = _override;
    if (pinned != null && !_retired.contains(pinned)) {
      final answer = await attempt(pinned);
      if (answer != null) return answer;
    }

    final candidates = (await _resolveCandidates())
        .where((model) => !_retired.contains(model))
        .take(maxModelsTried)
        .toList();

    if (candidates.isEmpty && tried.isEmpty) {
      throw const ExtractionException(
        'Nook could not reach a working AI model. Check that the Generative '
        'Language API is enabled for the key in GEMINI_API_KEY.',
      );
    }

    for (final model in candidates) {
      final answer = await attempt(model);
      if (answer != null) return answer;
    }

    throw ExtractionException(_friendly(last!, tried));
  }

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
          {
            'text':
                '$_instructions\n\n--- SOURCE ---\n'
                '${source.toPromptBlock()}--- END SOURCE ---',
          },
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
        'description':
            'The post\'s real human title or caption, copied from '
            'the source. Never an id, a URL or a filename.',
      },
      'caption': {
        'type': 'STRING',
        'nullable': true,
        'description':
            'The post\'s own description or caption text, kept as '
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
        'description':
            'The specific cafe, restaurant, shop, hotel or landmark '
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
        'description':
            'Two or three sentences about what a traveller finds, '
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
        'description':
            'Decimal degrees for the specific place or '
            'neighbourhood. Null unless the location is specific enough to '
            'have a single point.',
      },
      'longitude': {'type': 'NUMBER', 'nullable': true},
      'places': {
        'type': 'ARRAY',
        'nullable': true,
        'description':
            'Every specific place the source names — each cafe, '
            'restaurant, bar, shop, hotel or landmark it actually mentions. '
            'Empty when the source names none. Never invent one.',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING'},
            'kind': {
              'type': 'STRING',
              'nullable': true,
              'description':
                  'cafe, restaurant, bar, hotel, shop, landmark, '
                  'viewpoint, or other.',
            },
            'area': {
              'type': 'STRING',
              'nullable': true,
              'description': 'District, street or station, if given.',
            },
            'note': {
              'type': 'STRING',
              'nullable': true,
              'description': 'What the source said about it, briefly.',
            },
          },
          'required': ['name'],
        },
      },
      'highlights': {
        'type': 'ARRAY',
        'nullable': true,
        'description':
            'Activities, recommendations and practical tips the '
            'source gives, one short line each. Empty when it gives none.',
        'items': {'type': 'STRING'},
      },
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
- places: every specific venue the source names, in the order it names them. A
  post titled "5 Cafes in Kyoto" whose description lists five cafes should
  return five entries, each with whatever the source gives — a district, a
  station, a line about what it is known for. A post that says only "we visited
  a cafe in Osaka" names no venue, so places is empty and city is Osaka. Listing
  a place the source did not name is the worst thing you can do here.
- highlights: activities, recommendations and practical tips the source gives.
  One short line each, in the source's own terms. Empty when it gives none.
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
      // The reason code is a safety-filter category, not something anyone
      // pasting a link can act on.
      throw const ExtractionException(
        "Nook couldn't analyse this post. Try a different link, or enter the "
        'details yourself.',
      );
    }

    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const ExtractionException(
        "We couldn't analyse this post right now. Please try again, or enter "
        'the details yourself.',
      );
    }

    final candidate = candidates.first as Map;
    final finish = candidate['finishReason'];
    if (finish is String && finish != 'STOP' && finish != 'MAX_TOKENS') {
      throw const ExtractionException(
        "We couldn't finish analysing this post. Please try again.",
      );
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
      return trimmed.isEmpty || trimmed.toLowerCase() == 'null'
          ? null
          : trimmed;
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
    final placeable =
        latitude != null &&
        longitude != null &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180 &&
        !(latitude == 0 && longitude == 0);

    final places = _placesFrom(json['places']);
    final highlights = _highlightsFrom(json['highlights']);

    // A post can name a venue in its list without filling place_name; the first
    // place it names is the one the post is about.
    final placeName =
        string('place_name') ?? (places.isNotEmpty ? places.first.name : null);
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
        placeName != null ||
        neighbourhood != null ||
        city != null ||
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
      places: places,
      highlights: highlights,
    );
  }

  static List<PostPlace> _placesFrom(Object? value) {
    if (value is! List) return const [];
    return value
        .map(PostPlace.fromJson)
        .whereType<PostPlace>()
        .toList(growable: false);
  }

  static List<String> _highlightsFrom(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
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

  /// What the person reads when extraction cannot finish.
  ///
  /// Deliberately free of vendor names, model ids and HTTP status codes.
  /// "Server Error [503]: UNAVAILABLE" told someone pasting a TikTok link
  /// nothing they could act on. The rule here is: say what happened in their
  /// terms, and say what they can do — retry, wait, or type it in themselves.
  ///
  /// The two configuration failures are the exception. A rejected key and a
  /// disabled API are the developer's to fix, cannot be retried past, and the
  /// message is the only place that instruction can live — but even those name
  /// the `.env` setting rather than the service behind it.
  String _friendly(GeminiApiException e, List<String> tried) {
    if (e.isAuthFailure) {
      return 'Nook could not authenticate with its AI service. Check '
          'GEMINI_API_KEY in your .env file.';
    }
    if (e.status == 429 || e.code == 'RESOURCE_EXHAUSTED') {
      return "Nook has hit today's limit for analysing posts. It resets on its "
          'own — try again in a little while, or enter the details yourself.';
    }
    if (e.isModelUnavailable) {
      return 'Nook could not reach a working AI model. Check GEMINI_MODEL in '
          'your .env file, or leave it blank to let Nook choose.';
    }
    if (e.isTransient) {
      return "We couldn't analyse this post right now. Nook tried a few times "
          'and the service stayed busy. Please try again in a moment, or '
          'enter the details yourself.';
    }
    return "We couldn't analyse this post right now. Please try again, or "
        'enter the details yourself.';
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
