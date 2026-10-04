import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/ai/gemini_api.dart';
import 'package:nook/ai/gemini_itinerary_generator.dart';
import 'package:nook/ai/itinerary.dart';
import 'package:nook/ai/itinerary_generator.dart';
import 'package:nook/ai/post_place.dart';
import 'package:nook/ai/sample_itinerary_generator.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/explore/itinerary_context.dart';

/// Planning a trip from the posts already saved into it.
///
/// Three things are worth holding to: the day count the traveller chose is the
/// day count they get, the plan is built from their own saved material rather
/// than from the destination's reputation, and nothing the model does to the
/// reply reaches the screen as a crash.

const _fast = RetryPolicy(
  maxAttempts: 3,
  baseDelay: Duration(milliseconds: 4),
  maxDelay: Duration(milliseconds: 40),
  attemptTimeout: Duration(seconds: 2),
  deadline: Duration(seconds: 5),
);

ItinerarySource _source({
  String title = 'This Beach in Palawan Looks Fake',
  String? caption = 'A limestone cove reachable only by outrigger.',
  String? placeName = 'El Nido',
  String? note,
  List<PostPlace> places = const [
    PostPlace(name: 'Big Lagoon', kind: 'viewpoint', area: 'Miniloc Island'),
    PostPlace(name: 'Nacpan Beach', area: '40 minutes north'),
  ],
  List<String> highlights = const [
    'Go early — the day-tour boats arrive by eleven',
  ],
}) => ItinerarySource(
  title: title,
  caption: caption,
  placeName: placeName,
  neighbourhood: 'Bacuit Bay',
  city: 'El Nido',
  country: 'Philippines',
  bestTime: 'December–March',
  budgetNote: '~P2,500/day',
  note: note,
  places: places,
  highlights: highlights,
);

ItineraryRequest _request({int days = 3, List<ItinerarySource>? sources}) =>
    ItineraryRequest(
      destination: 'El Nido, Philippines',
      days: days,
      tripName: 'Someday List',
      sources: sources ?? [_source()],
    );

String _reply({required int days, String? overview}) => jsonEncode({
  'candidates': [
    {
      'finishReason': 'STOP',
      'content': {
        'parts': [
          {
            'text': jsonEncode({
              'overview': ?overview,
              'days': [
                for (var day = 1; day <= days; day++)
                  {
                    'day': day,
                    'title': 'Day $day in Bacuit Bay',
                    'activities': [
                      {
                        'title': 'Big Lagoon',
                        'description': 'Paddled rather than motored.',
                        'location': 'Miniloc Island',
                        'timing': 'Morning',
                      },
                      {
                        'title': 'Nacpan Beach',
                        'description': 'Four kilometres of sand.',
                      },
                    ],
                  },
              ],
            }),
          },
        ],
      },
    },
  ],
});

String _errorBody(int code, String status, String message, {String? reason}) =>
    jsonEncode({
      'error': {
        'code': code,
        'message': message,
        'status': status,
        if (reason != null)
          'details': [
            {'reason': reason},
          ],
      },
    });

/// Answers model calls from a script, and records what was asked.
class _Server {
  _Server(this.script);

  final List<http.Response Function(http.Request)> script;
  final requests = <http.Request>[];

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final index = calls.length - 1;
    return script[index < script.length ? index : script.length - 1](request);
  });

  List<http.Request> get calls => requests
      .where((r) => r.url.path.contains(':generateContent'))
      .toList(growable: false);

  Map<String, Object?> get lastBody =>
      jsonDecode(calls.last.body) as Map<String, Object?>;

  String get lastPrompt {
    final contents = lastBody['contents'] as List;
    final parts = (contents.first as Map)['parts'] as List;
    return (parts.first as Map)['text'] as String;
  }
}

http.Response _ok(String body) =>
    http.Response(body, 200, headers: {'content-type': 'application/json'});

http.Response _fail(int status, String body) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

GeminiItineraryGenerator _generator(_Server server) =>
    GeminiItineraryGenerator(
      apiKey: 'k',
      // Pinned, so a script does not have to answer a catalogue lookup first.
      model: 'gemini-flash-latest',
      httpClient: server.client,
      retry: _fast,
    );

void main() {
  group('the request carries the trip', () {
    test('the prompt states the day count the traveller chose', () async {
      final server = _Server([(_) => _ok(_reply(days: 5))]);
      await _generator(server).generate(_request(days: 5));

      expect(server.lastPrompt, contains('DAYS REQUESTED: 5'));
      expect(server.lastPrompt, contains('Return exactly 5 days'));
    });

    test('the prompt carries the saved posts, not just the place', () async {
      final server = _Server([(_) => _ok(_reply(days: 3))]);
      await _generator(server).generate(_request());

      final prompt = server.lastPrompt;
      expect(prompt, contains('This Beach in Palawan Looks Fake'));
      expect(prompt, contains('limestone cove'));
      expect(prompt, contains('Big Lagoon'));
      expect(prompt, contains('Nacpan Beach'));
      expect(prompt, contains('day-tour boats arrive by eleven'));
      expect(prompt, contains('December–March'));
    });

    test("the traveller's own note is passed through and flagged", () async {
      final server = _Server([(_) => _ok(_reply(days: 3))]);
      await _generator(server).generate(
        _request(sources: [_source(note: 'Ask Mia about the north beach')]),
      );

      expect(server.lastPrompt, contains('Ask Mia about the north beach'));
      expect(server.lastPrompt, contains("TRAVELLER'S OWN NOTE"));
    });

    test('the reply is asked for as JSON against a schema', () async {
      final server = _Server([(_) => _ok(_reply(days: 3))]);
      await _generator(server).generate(_request());

      final config = server.lastBody['generationConfig'] as Map;
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseSchema'], isA<Map>());
      expect(config['maxOutputTokens'], isA<int>());
      expect(
        (config['thinkingConfig'] as Map)['thinkingBudget'],
        0,
        reason: 'thinking is what made extraction time out; same budget here',
      );
    });
  });

  group('the reply becomes days', () {
    test('a well-formed plan parses, in order', () async {
      final server = _Server([
        (_) => _ok(_reply(days: 3, overview: 'Three slow days in Bacuit Bay.')),
      ]);
      final itinerary = await _generator(server).generate(_request());

      expect(itinerary.dayCount, 3);
      expect(itinerary.days.map((d) => d.day), [1, 2, 3]);
      expect(itinerary.overview, 'Three slow days in Bacuit Bay.');
      expect(itinerary.isSample, isFalse);
      expect(itinerary.destination, 'El Nido, Philippines');
      expect(itinerary.sourceCount, 1);
      expect(itinerary.days.first.activities, isNotEmpty);
      expect(itinerary.days.first.activities.first.title, 'Big Lagoon');
      expect(itinerary.days.first.activities.first.location, 'Miniloc Island');
      expect(itinerary.days.first.activities.first.timing, 'Morning');
    });

    test('more days than asked for are trimmed to the choice', () async {
      final server = _Server([(_) => _ok(_reply(days: 6))]);
      final itinerary = await _generator(server).generate(_request(days: 3));
      expect(itinerary.dayCount, 3);
    });

    test('fewer days than asked for is reported, not padded', () async {
      final server = _Server([(_) => _ok(_reply(days: 2))]);
      await expectLater(
        _generator(server).generate(_request(days: 5)),
        throwsA(
          isA<ItineraryException>().having(
            (e) => e.message,
            'message',
            allOf(contains('2 days instead of 5'), contains('again')),
          ),
        ),
      );
    });

    test('days are renumbered, so a repeated number cannot show', () {
      final days = ItineraryParsing.daysFrom([
        {
          'day': 3,
          'title': 'Third',
          'activities': [
            {'title': 'a', 'description': 'a'},
          ],
        },
        {
          'day': 3,
          'title': 'Also third',
          'activities': [
            {'title': 'b', 'description': 'b'},
          ],
        },
      ]);
      expect(days.map((d) => d.day), [1, 2]);
    });

    test('a day with no activities is dropped rather than drawn empty', () {
      final days = ItineraryParsing.daysFrom([
        {'day': 1, 'title': 'Empty', 'activities': <Object>[]},
        {
          'day': 2,
          'title': 'Real',
          'activities': [
            {'title': 'a', 'description': 'a'},
          ],
        },
      ]);
      expect(days, hasLength(1));
      expect(days.first.title, 'Real');
    });

    test('runaway content is cut rather than allowed to break a card', () {
      final days = ItineraryParsing.daysFrom([
        {
          'day': 1,
          'title': 'x' * 900,
          'activities': [
            {'title': 'y' * 900, 'description': 'z' * 4000},
          ],
        },
      ]);
      expect(
        days.first.title.length,
        lessThanOrEqualTo(ItineraryParsing.maxTitle + 1),
      );
      expect(
        days.first.activities.first.description.length,
        lessThanOrEqualTo(ItineraryParsing.maxDescription + 1),
      );
    });
  });

  group('every way it can fail', () {
    test('a plan that is not JSON is reported, not half-read', () async {
      final server = _Server([
        (_) => _ok(
          jsonEncode({
            'candidates': [
              {
                'finishReason': 'STOP',
                'content': {
                  'parts': [
                    {'text': 'not json at all'},
                  ],
                },
              },
            ],
          }),
        ),
      ]);
      await expectLater(
        _generator(server).generate(_request()),
        throwsA(isA<ItineraryException>()),
      );
    });

    test('an empty reply is reported', () async {
      final server = _Server([
        (_) => _ok(jsonEncode({'candidates': <Object>[]})),
      ]);
      await expectLater(
        _generator(server).generate(_request()),
        throwsA(isA<ItineraryException>()),
      );
    });

    test('a plan with no days in it is reported', () async {
      final server = _Server([
        (_) => _ok(
          jsonEncode({
            'candidates': [
              {
                'finishReason': 'STOP',
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({'days': <Object>[]}),
                    },
                  ],
                },
              },
            ],
          }),
        ),
      ]);
      await expectLater(
        _generator(server).generate(_request()),
        throwsA(isA<ItineraryException>()),
      );
    });

    test('a blocked prompt does not leak the filter category', () async {
      final server = _Server([
        (_) => _ok(
          jsonEncode({
            'promptFeedback': {'blockReason': 'SAFETY'},
          }),
        ),
      ]);
      try {
        await _generator(server).generate(_request());
        fail('expected an ItineraryException');
      } on ItineraryException catch (e) {
        expect(e.message.toLowerCase(), isNot(contains('safety')));
        expect(e.message.toLowerCase(), contains('plan'));
      }
    });

    test('a rejected key fails at once and names the setting', () async {
      final server = _Server([
        (_) => _fail(
          400,
          _errorBody(
            400,
            'INVALID_ARGUMENT',
            'API key not valid',
            reason: 'API_KEY_INVALID',
          ),
        ),
      ]);
      try {
        await _generator(server).generate(_request());
        fail('expected an ItineraryException');
      } on ItineraryException catch (e) {
        expect(e.message, contains('GEMINI_API_KEY'));
      }
      expect(server.calls, hasLength(1), reason: 'a bad key is not retried');
    });

    test('a busy service is retried, then reported in plain words', () async {
      final overloaded = _errorBody(503, 'UNAVAILABLE', 'high demand');
      final server = _Server([(_) => _fail(503, overloaded)]);
      try {
        await _generator(server).generate(_request());
        fail('expected an ItineraryException');
      } on ItineraryException catch (e) {
        expect(server.calls.length, greaterThan(1));
        final lower = e.message.toLowerCase();
        for (final word in [
          'gemini',
          'http',
          '503',
          '429',
          'unavailable',
          'json',
          'token',
        ]) {
          expect(lower, isNot(contains(word)), reason: 'leaked "$word"');
        }
        expect(lower, contains('try again'));
      }
    });

    test('a rate limit says so without blaming the key', () async {
      final server = _Server([
        (_) => _fail(429, _errorBody(429, 'RESOURCE_EXHAUSTED', 'quota')),
      ]);
      try {
        await _generator(server).generate(_request());
        fail('expected an ItineraryException');
      } on ItineraryException catch (e) {
        expect(e.message, contains("today's limit"));
        expect(e.message, isNot(contains('GEMINI_API_KEY')));
      }
    });

    test('nothing saved is refused before a call is made', () async {
      final server = _Server([(_) => _ok(_reply(days: 3))]);
      await expectLater(
        _generator(server).generate(
          ItineraryRequest(
            destination: 'El Nido',
            days: 3,
            sources: const [],
          ),
        ),
        throwsA(
          isA<ItineraryException>().having(
            (e) => e.message,
            'message',
            contains('nothing saved'),
          ),
        ),
      );
      expect(server.calls, isEmpty, reason: 'no sources is not billable');
    });

    test('titles with no detail are refused before a call is made', () async {
      final server = _Server([(_) => _ok(_reply(days: 3))]);
      await expectLater(
        _generator(server).generate(
          _request(
            sources: [
              const ItinerarySource(title: 'Some post'),
              const ItinerarySource(title: 'Another post'),
            ],
          ),
        ),
        throwsA(
          isA<ItineraryException>().having(
            (e) => e.message,
            'message',
            contains('only titles'),
          ),
        ),
      );
      expect(server.calls, isEmpty);
    });

    test('phases are reported in order, and only the three', () async {
      final server = _Server([(_) => _ok(_reply(days: 3))]);
      final seen = <ItineraryPhase>[];
      await _generator(server).generate(_request(), onStage: seen.add);

      expect(seen.first, ItineraryPhase.readingSaves);
      expect(seen.last, ItineraryPhase.finishing);
      expect(seen, contains(ItineraryPhase.planning));
      expect(seen.toSet().length, lessThanOrEqualTo(3));
    });

    test('two identical requests at once make one call', () async {
      final server = _Server([(_) => _ok(_reply(days: 3))]);
      final generator = _generator(server);

      final both = await Future.wait([
        generator.generate(_request()),
        generator.generate(_request()),
      ]);

      expect(server.calls, hasLength(1));
      expect(both.first.dayCount, 3);
      expect(both.last.dayCount, 3);
    });

    test('a different day count is a different request', () async {
      final server = _Server([
        (r) => _ok(
          _reply(days: (jsonDecode(r.body) as Map).toString().contains(
                'DAYS REQUESTED: 5',
              )
              ? 5
              : 3),
        ),
      ]);
      final generator = _generator(server);

      final three = await generator.generate(_request(days: 3));
      final five = await generator.generate(_request(days: 5));

      expect(three.dayCount, 3);
      expect(five.dayCount, 5);
      expect(server.calls, hasLength(2));
    });
  });

  group('the sample planner', () {
    const planner = SampleItineraryGenerator();

    test('is honest about what it is', () async {
      final itinerary = await planner.generate(_request());
      expect(planner.isLive, isFalse);
      expect(itinerary.isSample, isTrue);
    });

    for (final days in [1, 2, 3, 4, 5, 6, 7]) {
      test('gives exactly $days ${days == 1 ? 'day' : 'days'}', () async {
        final itinerary = await planner.generate(_request(days: days));
        expect(itinerary.dayCount, days);
        expect(itinerary.days.map((d) => d.day), [
          for (var i = 1; i <= days; i++) i,
        ]);
        for (final day in itinerary.days) {
          expect(
            day.activities.length,
            greaterThanOrEqualTo(2),
            reason: 'day ${day.day} has too little on it',
          );
          expect(day.title.trim(), isNotEmpty);
        }
      });
    }

    test('plans around the places in the saved posts', () async {
      final itinerary = await planner.generate(_request(days: 3));
      final text = itinerary.days
          .expand((day) => day.activities)
          .map((a) => '${a.title} ${a.description} ${a.location}')
          .join(' ');

      expect(text, contains('Big Lagoon'));
      expect(text, contains('Nacpan Beach'));
      expect(text, contains('day-tour boats'));
    });

    test('keeps every saved place somewhere in the plan', () async {
      final sources = [
        _source(
          places: const [
            PostPlace(name: 'Alpha Cove'),
            PostPlace(name: 'Beta Beach'),
            PostPlace(name: 'Gamma Point'),
            PostPlace(name: 'Delta Bay'),
            PostPlace(name: 'Epsilon Reef'),
          ],
        ),
      ];
      final itinerary = await planner.generate(
        _request(days: 2, sources: sources),
      );
      final text = itinerary.days
          .expand((day) => day.activities)
          .map((a) => a.title)
          .join(' ');

      for (final place in [
        'Alpha Cove',
        'Beta Beach',
        'Gamma Point',
        'Delta Bay',
        'Epsilon Reef',
      ]) {
        expect(text, contains(place), reason: '$place was dropped');
      }
    });

    test('is deterministic, so the same trip plans the same way', () async {
      final first = await planner.generate(_request(days: 4));
      final second = await planner.generate(_request(days: 4));

      String flatten(GeneratedItinerary it) => it.days
          .map((d) => '${d.day}|${d.title}|'
              '${d.activities.map((a) => a.title).join(',')}')
          .join('\n');

      expect(flatten(first), flatten(second));
    });

    test('refuses an empty trip and a trip of bare titles', () async {
      await expectLater(
        planner.generate(
          const ItineraryRequest(destination: 'X', days: 3, sources: []),
        ),
        throwsA(isA<ItineraryException>()),
      );
      await expectLater(
        planner.generate(
          _request(sources: [const ItinerarySource(title: 'Bare')]),
        ),
        throwsA(isA<ItineraryException>()),
      );
    });
  });

  group('the trip context', () {
    late NookDatabase db;

    setUp(() async {
      db = NookDatabase.forTesting(NativeDatabase.memory());
      await db.customStatement('PRAGMA foreign_keys = ON');
    });
    tearDown(() => db.close());

    test('a saved post reaches the planner with its extraction', () async {
      final posts = await PostsDao(db).watchAll().first;
      final kyoto = posts.firstWhere((p) => p.title.contains('5 Hidden Cafes'));
      final source = ItineraryContext.sourceOf(kyoto);

      expect(source.title, kyoto.title);
      expect(source.city, kyoto.aiCity);
      expect(source.country, kyoto.aiCountry);
      expect(source.placeName, kyoto.aiPlaceName);
      expect(source.bestTime, kyoto.aiBestTime);
      expect(source.budgetNote, kyoto.aiBudgetNote);
      expect(source.note, kyoto.personalNote);
      expect(source.hasDetail, isTrue);
    });

    test('the destination is the commonest, not the first', () async {
      final id = await PostsDao(db).insertPost(
        SavedPostsCompanion.insert(
          title: 'Odd one out',
          platform: 'other',
          importMethod: 'note',
          dateSaved: DateTime.now(),
          aiCity: const Value('Reykjavik'),
        ),
      );
      final posts = await PostsDao(db).watchAll().first;
      final kyoto = posts
          .where((p) => p.aiCity == 'Kyoto')
          .toList(growable: false);
      final odd = posts.firstWhere((p) => p.id == id);

      expect(
        ItineraryContext.destinationOf([odd, ...kyoto]),
        'Kyoto',
        reason: 'one stray post must not get to name the trip',
      );
    });

    test('a request is built from a trip and a day count', () async {
      final posts = await PostsDao(db).watchByTrip(1).first;
      final request = ItineraryContext.requestFor(
        tripName: 'Japan 2027',
        posts: posts,
        days: 4,
      );

      expect(request.days, 4);
      expect(request.sources, hasLength(posts.length));
      expect(request.tripName, 'Japan 2027');
      expect(request.hasSources, isTrue);
      expect(request.hasEnoughDetail, isTrue);
      expect(request.toPromptBlock(), contains('DAYS REQUESTED: 4'));
    });

    test('a trip of bare titles is reported as having no detail', () {
      final request = ItineraryRequest(
        destination: 'Nowhere',
        days: 3,
        sources: const [ItinerarySource(title: 'Just a title')],
      );
      expect(request.hasSources, isTrue);
      expect(request.hasEnoughDetail, isFalse);
      expect(request.usableSources, isEmpty);
    });

    test('a real seeded trip plans end to end', () async {
      final posts = await PostsDao(db).watchByTrip(1).first;
      final itinerary = await const SampleItineraryGenerator().generate(
        ItineraryContext.requestFor(
          tripName: 'Japan 2027',
          posts: posts,
          days: 3,
        ),
      );

      expect(itinerary.dayCount, 3);
      expect(itinerary.activityCount, greaterThanOrEqualTo(6));
      expect(itinerary.sourceCount, posts.length);
    });
  });
}
