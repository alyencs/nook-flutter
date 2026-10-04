import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gemini_api.dart';
import 'itinerary.dart';
import 'itinerary_generator.dart';

/// Builds a day-by-day plan out of what the traveller has already saved.
///
/// The same transport as extraction — [GeminiClient], its retry policy and its
/// status handling — so there is one place in the app that knows how to talk to
/// the model and one place that decides whether a failure is worth retrying.
///
/// What differs from extraction is the budget. Extraction copies a handful of
/// short fields out of text that is already in the prompt; this reads several
/// posts and has to organise them, so the reply is longer and the wait is
/// longer, and the timeouts say so rather than inheriting a 20-second cap set
/// for a different job.
class GeminiItineraryGenerator implements ItineraryGenerator {
  GeminiItineraryGenerator({
    required String apiKey,
    String? model,
    http.Client? httpClient,
    RetryPolicy retry = planningRetry,
  }) : _override = _clean(model),
       _client = GeminiClient(
         apiKey: apiKey,
         httpClient: httpClient,
         retry: retry,
       );

  /// Longer than extraction's, because the job is bigger. Three attempts
  /// rather than four: a plan that has failed twice is not usually one wait
  /// away from working, and the traveller is watching a spinner.
  static const planningRetry = RetryPolicy(
    maxAttempts: 3,
    baseDelay: Duration(milliseconds: 800),
    maxDelay: Duration(seconds: 8),
    attemptTimeout: Duration(seconds: 45),
    deadline: Duration(seconds: 100),
  );

  /// Room for a long trip. Seven days of four activities with a sentence each
  /// sits comfortably inside this; an uncapped reply is one that can run until
  /// it times out.
  static const maxOutputTokens = 6144;

  /// How many days the traveller may ask for.
  ///
  /// Not an arbitrary ceiling: beyond about a week the plan stops being an
  /// itinerary and becomes a list, and the saved posts behind it run out of
  /// material long before that.
  static const maxDays = 7;

  final String? _override;
  final GeminiClient _client;

  Future<List<String>>? _candidates;
  final _retired = <String>{};
  final _noThinking = <String>{};

  /// Plans currently running, keyed by destination and day count.
  ///
  /// Two taps on Generate, or a tap and a re-tap while the spinner is up, must
  /// not become two billable calls. The second caller joins the first.
  final _inFlight = <String, Future<GeneratedItinerary>>{};

  static const maxModelsTried = 3;

  @override
  bool get isLive => true;

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<GeneratedItinerary> generate(
    ItineraryRequest request, {
    ItineraryStage? onStage,
  }) {
    final key = '${request.destination}|${request.days}';
    final existing = _inFlight[key];
    if (existing != null) {
      onStage?.call(ItineraryPhase.planning);
      return existing;
    }

    final future = _generate(request, onStage);
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  Future<GeneratedItinerary> _generate(
    ItineraryRequest request,
    ItineraryStage? onStage,
  ) async {
    onStage?.call(ItineraryPhase.readingSaves);

    if (!request.hasSources) {
      throw const ItineraryException(
        'There is nothing saved to this trip yet. Save a few posts about the '
        'place first, and Nook can plan around them.',
      );
    }
    if (!request.hasEnoughDetail) {
      throw const ItineraryException(
        'The posts saved here are only titles, so there is not enough to plan '
        'from yet. Open one and add what you know, or save a post with more '
        'detail in it.',
      );
    }

    final json = await _ask(request, onStage);

    onStage?.call(ItineraryPhase.finishing);
    return _itineraryFrom(json, request);
  }

  /// Asks each candidate model in turn until one answers.
  ///
  /// Lifted from the extractor deliberately: a retired model moves to the next
  /// candidate, an overloaded one moves on because another model is a different
  /// pool, and a rejected key or an exhausted quota stops rather than failing
  /// the same way three times.
  Future<Map<String, dynamic>> _ask(
    ItineraryRequest request,
    ItineraryStage? onStage,
  ) async {
    final tried = <String>[];
    GeminiApiException? last;

    Future<Map<String, dynamic>?> attempt(String model) async {
      tried.add(model);
      onStage?.call(ItineraryPhase.planning);
      try {
        return await _client.generateContent(
          model: model,
          body: _requestBody(request, thinking: !_noThinking.contains(model)),
          onRetry: (attempt, of, wait) =>
              onStage?.call(ItineraryPhase.planning),
        );
      } on GeminiApiException catch (e) {
        last = e;

        if (e.isThinkingUnsupported && _noThinking.add(model)) {
          return _client.generateContent(
            model: model,
            body: _requestBody(request, thinking: false),
            onRetry: (attempt, of, wait) =>
                onStage?.call(ItineraryPhase.planning),
          );
        }

        if (e.isModelUnavailable) {
          _retired.add(model);
          return null;
        }

        if (e.isModelOverloaded) return null;

        throw ItineraryException(_friendly(e));
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
      throw const ItineraryException(
        'Nook could not reach a working AI model. Check that the Generative '
        'Language API is enabled for the key in GEMINI_API_KEY.',
      );
    }

    for (final model in candidates) {
      final answer = await attempt(model);
      if (answer != null) return answer;
    }

    throw ItineraryException(_friendly(last!));
  }

  Future<List<String>> _resolveCandidates() {
    return _candidates ??= () async {
      List<String> discovered;
      try {
        discovered = GeminiModels.rank(await _client.listModels());
      } on GeminiApiException {
        discovered = const [];
      }
      return discovered.isEmpty ? GeminiModels.fallback : discovered;
    }();
  }

  Map<String, Object?> _requestBody(
    ItineraryRequest request, {
    bool thinking = true,
  }) => {
    'contents': [
      {
        'role': 'user',
        'parts': [
          {
            'text':
                '${_instructions(request.days)}\n\n--- TRIP ---\n'
                '${request.toPromptBlock()}--- END TRIP ---',
          },
        ],
      },
    ],
    'generationConfig': {
      // Not zero, unlike extraction. Extraction copies facts and has one right
      // answer, so sampling there was pure variance. Writing an itinerary is a
      // choice about order and pacing, and a little room makes the difference
      // between a plan and a sorted list. Low enough that it still respects
      // the sources.
      'temperature': 0.4,
      'seed': 7,
      'responseMimeType': 'application/json',
      'responseSchema': _responseSchema,
      'maxOutputTokens': maxOutputTokens,
      // The same fix extraction needed. Gemini 2.5 models think by default and
      // nothing here asks them to stop, which on a reply this size is seconds
      // of invisible tokens spent on a shape already handed over.
      if (thinking) 'thinkingConfig': {'thinkingBudget': 0},
    },
  };

  static final Map<String, Object?> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'overview': {
        'type': 'STRING',
        'nullable': true,
        'description':
            'One sentence on the shape of the trip. Null if there is '
            'nothing worth saying beyond the days themselves.',
      },
      'days': {
        'type': 'ARRAY',
        'description': 'Exactly as many entries as DAYS REQUESTED, in order.',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'day': {'type': 'INTEGER', 'description': 'From 1 upwards.'},
            'title': {
              'type': 'STRING',
              'description':
                  'A short name for the day, drawn from what is on it: '
                  '"Arrival and Sunset Chill", "Island Hopping Tour A".',
            },
            'activities': {
              'type': 'ARRAY',
              'description': 'Two to five, in the order they happen.',
              'items': {
                'type': 'OBJECT',
                'properties': {
                  'title': {
                    'type': 'STRING',
                    'description': 'What the traveller does. Short.',
                  },
                  'description': {
                    'type': 'STRING',
                    'description':
                        'One or two sentences of practical detail, taken '
                        'from the saved posts wherever they supply it.',
                  },
                  'location': {
                    'type': 'STRING',
                    'nullable': true,
                    'description':
                        'The place this happens, named as the posts name it. '
                        'Null when the activity is not tied to one.',
                  },
                  'timing': {
                    'type': 'STRING',
                    'nullable': true,
                    'description':
                        'When, if the posts say or it follows obviously: '
                        '"Morning", "9:00 AM - 4:00 PM", "After dark".',
                  },
                },
                'required': ['title', 'description'],
              },
            },
          },
          'required': ['day', 'title', 'activities'],
        },
      },
    },
    'required': ['days'],
  };

  static String _instructions(int days) =>
      '''
You plan trips for Nook, a travel app. The TRIP block below holds everything
one traveller has saved about one destination: posts they kept from TikTok,
Instagram, Facebook and YouTube, the places those posts named, the tips in
them, and any notes the traveller wrote themselves.

Turn that material into a $days-day itinerary.

- Return exactly $days days, numbered 1 to $days. Not more, not fewer.
- Build the plan out of the saved posts. The places, venues, tips, seasons and
  prices in them are the point: a traveller who saved five cafes wants those
  cafes, not five different ones you happen to know.
- Where the posts leave an obvious gap — getting there on day one, somewhere to
  eat near a place they saved — you may fill it with what you know about the
  destination. Keep it secondary to their own material, and keep it plausible.
- Never contradict a saved post. If one says a tour runs 9am to 4pm, it runs
  9am to 4pm.
- A traveller's own note outranks everything else in the post it belongs to.
- Order each day so it works on the ground: things that are near each other on
  the same day, an early start before a long day, arrival before activity,
  a slower last day where that makes sense.
- Give each day a short title that says what it is.
- Two to five activities per day. A day with one line in it is not a day, and
  a day with nine is a list.
- Spread the material across the days rather than front-loading it. With more
  days than the posts strictly support, slow the pace and add rest, local
  wandering and a day trip; do not repeat an activity.
- Write descriptions a traveller can act on: where, roughly when, and what to
  expect. One or two sentences.
- Do not invent prices, opening hours or addresses that no post mentions.

Return JSON only, matching the schema.
''';

  /// Digs the plan out of the response envelope.
  ///
  /// The same envelope extraction reads, and the same three ways it can be
  /// well-formed HTTP and still carry no answer: a blocked prompt, a candidate
  /// cut off at the token limit, a part list with no text in it.
  GeneratedItinerary _itineraryFrom(
    Map<String, dynamic> response,
    ItineraryRequest request,
  ) {
    final blockReason = (response['promptFeedback'] as Map?)?['blockReason'];
    if (blockReason != null) {
      throw const ItineraryException(
        "Nook couldn't plan this trip. Try a different number of days, or "
        'build it yourself from the posts you saved.',
      );
    }

    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const ItineraryException(
        "We couldn't build an itinerary right now. Please try again.",
      );
    }

    final candidate = candidates.first as Map;
    final finish = candidate['finishReason'];
    if (finish is String && finish != 'STOP' && finish != 'MAX_TOKENS') {
      throw const ItineraryException(
        "We couldn't finish planning this trip. Please try again.",
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
      throw const ItineraryException('The itinerary came back empty.');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const ItineraryException(
        "The itinerary couldn't be read. Please try again.",
      );
    }

    var days = ItineraryParsing.daysFrom(json['days']);

    if (days.isEmpty) {
      throw const ItineraryException(
        'The itinerary came back without any days in it. Please try again.',
      );
    }

    // More than asked for is trimmed — the extra days are a model that kept
    // going, and the traveller chose a number. Fewer is reported, because
    // padding it would mean inventing a day nobody planned.
    if (days.length > request.days) {
      days = days.take(request.days).toList(growable: false);
    } else if (days.length < request.days) {
      throw ItineraryException(
        'The plan came back with ${days.length} '
        '${days.length == 1 ? 'day' : 'days'} instead of ${request.days}. '
        'Try generating it again.',
      );
    }

    return GeneratedItinerary(
      destination: request.destination,
      days: days,
      isSample: false,
      overview: ItineraryParsing.overviewFrom(json['overview']),
      sourceCount: request.sources.length,
    );
  }

  /// What the traveller reads when a plan cannot be built.
  ///
  /// Free of vendor names, model ids and status codes, like every other
  /// message in the app. The two configuration failures are the exception and
  /// name the `.env` setting rather than the service behind it.
  String _friendly(GeminiApiException e) {
    if (e.isAuthFailure) {
      return 'Nook could not authenticate with its AI service. Check '
          'GEMINI_API_KEY in your .env file.';
    }
    if (e.status == 429 || e.code == 'RESOURCE_EXHAUSTED') {
      return "Nook has hit today's limit for planning trips. It resets on its "
          'own — try again in a little while.';
    }
    if (e.isModelUnavailable) {
      return 'Nook could not reach a working AI model. Check GEMINI_MODEL in '
          'your .env file, or leave it blank to let Nook choose.';
    }
    if (e.isTransient) {
      return "We couldn't build an itinerary right now. Nook tried a few times "
          'and the service stayed busy. Please try again in a moment.';
    }
    return "We couldn't build an itinerary right now. Please try again.";
  }
}
