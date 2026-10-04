import 'dart:async';

import 'package:http/http.dart' as http;

import 'claude_api.dart';
import 'itinerary.dart';
import 'itinerary_generator.dart';

/// Builds a day-by-day plan out of what the traveller has already saved.
///
/// The same transport as extraction — [ClaudeClient], its retry policy and its
/// status handling — so there is one place in the app that knows how to talk to
/// the model and one place that decides whether a failure is worth retrying.
///
/// What differs from extraction is the budget. Extraction copies a handful of
/// short fields out of text that is already in the prompt; this reads several
/// posts and has to organise them, so the reply is longer and the wait is
/// longer, and the timeouts say so rather than inheriting a 20-second cap set
/// for a different job.
class ClaudeItineraryGenerator implements ItineraryGenerator {
  ClaudeItineraryGenerator({
    required String apiKey,
    String? model,
    http.Client? httpClient,
    RetryPolicy retry = planningRetry,
  }) : _candidates = ClaudeModels.candidates(model),
       _client = ClaudeClient(
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

  /// The name the model calls to hand the plan back. The reply is the tool's
  /// arguments, so there is no prose to find JSON inside of.
  static const toolName = 'record_itinerary';

  final List<String> _candidates;
  final ClaudeClient _client;

  /// Model ids that answered "no such model" this session, so a second plan
  /// does not spend an attempt rediscovering that.
  final _retired = <String>{};

  /// Plans currently running, keyed by destination and day count.
  ///
  /// Two taps on Generate, or a tap and a re-tap while the spinner is up, must
  /// not become two billable calls. The second caller joins the first.
  final _inFlight = <String, Future<GeneratedItinerary>>{};

  @override
  bool get isLive => true;

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

    final response = await _ask(request, onStage);

    onStage?.call(ItineraryPhase.finishing);
    return _itineraryFrom(response, request);
  }

  /// Asks each candidate model in turn until one answers.
  ///
  /// A model id that is gone moves to the next candidate, an overloaded service
  /// gets one more candidate because that is nearly free, and a rejected key or
  /// an exhausted quota stops rather than failing the same way three times.
  Future<Map<String, dynamic>> _ask(
    ItineraryRequest request,
    ItineraryStage? onStage,
  ) async {
    final tried = <String>[];
    ClaudeApiException? last;

    Future<Map<String, dynamic>?> attempt(String model) async {
      tried.add(model);
      onStage?.call(ItineraryPhase.planning);
      try {
        return await _client.createMessage(
          body: _requestBody(request, model),
          onRetry: (attempt, of, wait) =>
              onStage?.call(ItineraryPhase.planning),
        );
      } on ClaudeApiException catch (e) {
        last = e;

        if (e.isModelUnavailable) {
          _retired.add(model);
          return null;
        }

        // The client has already retried this with backoff. Another id is the
        // one thing left that might route around it, and it costs one call.
        if (e.isOverloaded) return null;

        throw ItineraryException(_friendly(e));
      }
    }

    final candidates = _candidates
        .where((model) => !_retired.contains(model))
        .toList();

    if (candidates.isEmpty) {
      throw const ItineraryException(
        'Nook could not reach a working AI model. Check CLAUDE_MODEL in your '
        '.env file, or leave it blank to use the default.',
      );
    }

    for (final model in candidates) {
      final answer = await attempt(model);
      if (answer != null) return answer;
    }

    throw ItineraryException(_friendly(last!));
  }

  Map<String, Object?> _requestBody(ItineraryRequest request, String model) =>
      claudeToolRequest(
        model: model,
        system: _instructions(request.days),
        prompt:
            '--- TRIP ---\n${request.toPromptBlock()}--- END TRIP ---',
        toolName: toolName,
        toolDescription:
            'Record the finished day-by-day itinerary. Call this exactly once, '
            'with every day the traveller asked for.',
        schema: _responseSchema,
        maxTokens: maxOutputTokens,
        // Not zero, unlike extraction. Extraction copies facts and has one
        // right answer, so sampling there was pure variance. Writing an
        // itinerary is a choice about order and pacing, and a little room makes
        // the difference between a plan and a sorted list. Low enough that it
        // still respects the sources.
        temperature: 0.4,
      );

  /// The shape the plan has to come back in, as JSON Schema.
  ///
  /// A nullable field is written as a two-member type rather than a flag, which
  /// is how JSON Schema says it and what the tool validator reads.
  static final Map<String, Object?> _responseSchema = {
    'type': 'object',
    'properties': {
      'overview': {
        'type': ['string', 'null'],
        'description':
            'One sentence on the shape of the trip. Null if there is '
            'nothing worth saying beyond the days themselves.',
      },
      'days': {
        'type': 'array',
        'description': 'Exactly as many entries as DAYS REQUESTED, in order.',
        'items': {
          'type': 'object',
          'properties': {
            'day': {'type': 'integer', 'description': 'From 1 upwards.'},
            'title': {
              'type': 'string',
              'description':
                  'A short name for the day, drawn from what is on it: '
                  '"Arrival and Sunset Chill", "Island Hopping Tour A".',
            },
            'activities': {
              'type': 'array',
              'description': 'Two to five, in the order they happen.',
              'items': {
                'type': 'object',
                'properties': {
                  'title': {
                    'type': 'string',
                    'description': 'What the traveller does. Short.',
                  },
                  'description': {
                    'type': 'string',
                    'description':
                        'One or two sentences of practical detail, taken '
                        'from the saved posts wherever they supply it.',
                  },
                  'location': {
                    'type': ['string', 'null'],
                    'description':
                        'The place this happens, named as the posts name it. '
                        'Null when the activity is not tied to one.',
                  },
                  'timing': {
                    'type': ['string', 'null'],
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

Hand the finished plan back by calling $toolName. Do not write the plan as
prose, and do not call it more than once.
''';

  /// Digs the plan out of the response envelope.
  ///
  /// Three ways a reply can be well-formed HTTP and still carry no answer: a
  /// refusal, a message cut off at the token ceiling before the tool call was
  /// finished, and a content list with no tool call in it at all.
  GeneratedItinerary _itineraryFrom(
    Map<String, dynamic> response,
    ItineraryRequest request,
  ) {
    final stop = stopReasonOf(response);

    if (stop == 'refusal') {
      throw const ItineraryException(
        "Nook couldn't plan this trip. Try a different number of days, or "
        'build it yourself from the posts you saved.',
      );
    }

    final json = claudeToolInput(response, toolName);

    if (json == null) {
      if (stop == 'max_tokens') {
        throw const ItineraryException(
          'This trip had more in it than we could plan in one go. Try fewer '
          'days, or generate it again.',
        );
      }
      throw const ItineraryException(
        "We couldn't build an itinerary right now. Please try again.",
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
  /// message in the app. The configuration failures are the exception and name
  /// the `.env` setting rather than the service behind it.
  String _friendly(ClaudeApiException e) {
    if (e.isAuthFailure) {
      return 'Nook could not authenticate with its AI service. Check '
          'ANTHROPIC_API_KEY in your .env file.';
    }
    if (e.isBillingFailure) {
      return 'Nook\'s AI service has no credit left on this key. Top it up and '
          'try again.';
    }
    if (e.status == 429 || e.type == 'rate_limit_error') {
      return "Nook has hit today's limit for planning trips. It resets on its "
          'own — try again in a little while.';
    }
    if (e.isModelUnavailable) {
      return 'Nook could not reach a working AI model. Check CLAUDE_MODEL in '
          'your .env file, or leave it blank to use the default.';
    }
    if (e.isTransient) {
      return "We couldn't build an itinerary right now. Nook tried a few times "
          'and the service stayed busy. Please try again in a moment.';
    }
    return "We couldn't build an itinerary right now. Please try again.";
  }
}
