import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/ai/ai_extractor.dart';
import 'package:nook/ai/gemini_api.dart';
import 'package:nook/ai/gemini_extractor.dart';

/// The Gemini transport, exercised against a scripted server.
///
/// The point of these tests is the part that could not be tested before: what
/// happens when the API says no. Every failure mode the brief lists — 429, 500,
/// 502, 503, 504, network loss, a body that is not JSON, a reply with no
/// candidate in it — is scripted here and the behaviour asserted, so "it retries
/// sensibly" is a checked fact rather than a claim.

/// A YouTube link: its thumbnail is derived from the video id with no network
/// call, so these tests never touch a real host.
const _url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

/// Fast enough that the whole file runs in under a second, while keeping the
/// shape of the real policy: four tries, growing waits, a hard deadline.
const _fast = RetryPolicy(
  maxAttempts: 4,
  baseDelay: Duration(milliseconds: 4),
  maxDelay: Duration(milliseconds: 40),
  attemptTimeout: Duration(seconds: 2),
  deadline: Duration(seconds: 5),
);

String _errorBody(int code, String status, String message,
        {String? reason}) =>
    jsonEncode({
      'error': {
        'code': code,
        'message': message,
        'status': status,
        if (reason != null)
          'details': [
            {'@type': 'type.googleapis.com/google.rpc.ErrorInfo', 'reason': reason},
          ],
      },
    });

/// The 503 the user actually saw, verbatim in shape.
String get _overloaded => _errorBody(
      503,
      'UNAVAILABLE',
      'This model is currently experiencing high demand. Spikes in demand are '
          'usually temporary. Please try again later.',
    );

String _extraction({String title = '5 Hidden Cafes in Kyoto'}) => jsonEncode({
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {
            'parts': [
              {
                'text': jsonEncode({
                  'title': title,
                  'creator': '@wanderwithmia',
                  'destination': 'Kyoto, Japan',
                  'country': 'Japan',
                  'category': 'Food',
                  'summary': 'Six cafes within a short walk of each other.',
                  'best_time': 'March-May',
                  'budget_note': '~JPY3,000/day',
                  'latitude': 35.0116,
                  'longitude': 135.7681,
                }),
              },
            ],
          },
        },
      ],
    });

String get _modelList => jsonEncode({
      'models': [
        {
          'name': 'models/gemini-2.5-flash-lite',
          'supportedGenerationMethods': ['generateContent'],
        },
      ],
    });

/// Records every request, and answers from a script.
class _Server {
  _Server(this.script);

  /// One entry per request, in order. The last entry repeats once exhausted.
  final List<http.Response Function(http.Request)> script;
  final requests = <http.Request>[];
  final at = <DateTime>[];

  http.Client get client => MockClient((request) async {
        requests.add(request);
        at.add(DateTime.now());
        final index = min(requests.length - 1, script.length - 1);
        return script[index](request);
      });

  int get calls => requests.length;
  List<http.Request> get generateCalls =>
      requests.where((r) => r.url.path.contains(':generateContent')).toList();
}

http.Response Function(http.Request) _reply(int status, String body,
        {Map<String, String>? headers}) =>
    (_) => http.Response(body, status,
        headers: {'content-type': 'application/json', ...?headers});

/// Answers ListModels normally, then runs [script] for the generate calls.
List<http.Response Function(http.Request)> _withModelList(
  List<http.Response Function(http.Request)> script,
) =>
    [_reply(200, _modelList), ...script];

GeminiExtractor _extractor(_Server server, {String? model}) => GeminiExtractor(
      apiKey: 'test-key',
      model: model,
      httpClient: server.client,
      retry: _fast,
    );

void main() {
  group('a 503 is retried, not surfaced', () {
    test('one 503 then a result: the user sees the result', () async {
      final server = _Server(_withModelList([
        _reply(503, _overloaded),
        _reply(200, _extraction()),
      ]));

      final result = await _extractor(server).extract(_url);

      expect(result.destination, 'Kyoto, Japan');
      expect(result.isSample, isFalse, reason: 'never fake a real extraction');
      expect(server.generateCalls, hasLength(2));
    });

    test('three 503s then a result still succeeds', () async {
      final server = _Server(_withModelList([
        _reply(503, _overloaded),
        _reply(503, _overloaded),
        _reply(503, _overloaded),
        _reply(200, _extraction()),
      ]));

      final result = await _extractor(server).extract(_url);

      expect(result.title, '5 Hidden Cafes in Kyoto');
      expect(server.generateCalls, hasLength(4));
    });

    test('retries stop at the limit and report a real failure', () async {
      final server = _Server(_withModelList([_reply(503, _overloaded)]));

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>().having(
          (e) => e.message,
          'message',
          allOf(contains('overloaded'), contains('retried')),
        )),
      );

      // Four tries, and no fifth: a failing call must not become a loop.
      expect(server.generateCalls, hasLength(_fast.maxAttempts));
    });

    test('the wait between tries grows instead of hammering', () async {
      final server = _Server(_withModelList([_reply(503, _overloaded)]));
      try {
        await _extractor(server).extract(_url);
      } on ExtractionException {
        // Expected: this test is about the gaps between the tries.
      }

      final generate = <DateTime>[];
      for (var i = 0; i < server.requests.length; i++) {
        if (server.requests[i].url.path.contains(':generateContent')) {
          generate.add(server.at[i]);
        }
      }
      final gaps = [
        for (var i = 1; i < generate.length; i++)
          generate[i].difference(generate[i - 1]),
      ];

      expect(gaps, hasLength(3));
      for (final gap in gaps) {
        expect(gap, greaterThan(Duration.zero),
            reason: 'a retry must never be immediate');
      }
      // Equal jitter halves each delay at worst, so growth is asserted across
      // the span rather than between adjacent pairs.
      expect(gaps.last, greaterThan(gaps.first));
    });
  });

  group('every failure mode the API can raise', () {
    for (final status in [500, 502, 503, 504, 429, 408]) {
      test('$status is treated as transient and retried', () async {
        final server = _Server(_withModelList([
          _reply(status, _errorBody(status, 'UNAVAILABLE', 'busy')),
          _reply(200, _extraction()),
        ]));

        await _extractor(server).extract(_url);
        expect(server.generateCalls, hasLength(2));
      });
    }

    test('a rejected key fails at once, with no retries', () async {
      final server = _Server(_withModelList([
        _reply(
          400,
          _errorBody(400, 'INVALID_ARGUMENT', 'API key not valid.',
              reason: 'API_KEY_INVALID'),
        ),
      ]));

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>().having(
          (e) => e.message,
          'message',
          contains('GEMINI_API_KEY'),
        )),
      );
      expect(server.generateCalls, hasLength(1),
          reason: 'a bad key will still be bad on the next try');
    });

    test('a rate limit says so, and does not blame the key', () async {
      final server = _Server(_withModelList([
        _reply(429, _errorBody(429, 'RESOURCE_EXHAUSTED', 'Quota exceeded.')),
      ]));

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>().having(
          (e) => e.message,
          'message',
          contains('rate limit'),
        )),
      );
    });

    test('Retry-After from the server is honoured', () async {
      final server = _Server(_withModelList([
        _reply(503, _overloaded, headers: {'retry-after': '1'}),
        _reply(200, _extraction()),
      ]));

      final started = DateTime.now();
      await _extractor(server).extract(_url);
      final elapsed = DateTime.now().difference(started);

      // The computed backoff here is 4ms; the server asked for a second.
      expect(elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 900)));
    });

    test('a network failure is retried, then reported honestly', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        throw const SocketishException();
      });
      final extractor = GeminiExtractor(
        apiKey: 'k',
        model: 'gemini-flash-latest',
        httpClient: client,
        retry: _fast,
      );

      await expectLater(
        extractor.extract(_url),
        throwsA(isA<ExtractionException>().having(
          (e) => e.message,
          'message',
          contains('could not be reached'),
        )),
      );
      // Four tries against the pinned model, and no catalogue lookup: a
      // network that is down cannot answer that question either.
      expect(calls, _fast.maxAttempts);
    });

    test('a 200 that is not JSON is not retried forever', () async {
      final server = _Server(_withModelList([
        _reply(200, '<html>proxy sign-in</html>'),
      ]));

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>()),
      );
      expect(server.generateCalls, hasLength(1));
    });

    test('a reply with no candidates is reported, not returned empty',
        () async {
      final server = _Server(_withModelList([_reply(200, jsonEncode({}))]));

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>().having(
          (e) => e.message,
          'message',
          contains('no result'),
        )),
      );
    });

    test('a blocked prompt says it was blocked', () async {
      final server = _Server(_withModelList([
        _reply(
          200,
          jsonEncode({
            'promptFeedback': {'blockReason': 'SAFETY'},
          }),
        ),
      ]));

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>().having(
          (e) => e.message,
          'message',
          contains('SAFETY'),
        )),
      );
    });

    test('model JSON that is not JSON is reported, not half-parsed', () async {
      final server = _Server(_withModelList([
        _reply(
          200,
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Sorry, I cannot do that.'},
                  ],
                },
              },
            ],
          }),
        ),
      ]));

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>().having(
          (e) => e.message,
          'message',
          contains("couldn't be read"),
        )),
      );
    });
  });

  group('a retired model moves on instead of failing', () {
    test('404 on the first model tries the next one', () async {
      final notFound = _errorBody(
        404,
        'NOT_FOUND',
        'models/gemini-2.0-flash is not found for API version v1beta, or is '
            'not supported for generateContent.',
      );
      final server = _Server([
        // ListModels offers two.
        _reply(
          200,
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-3.1-flash-lite',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/gemini-2.5-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
        ),
        _reply(404, notFound),
        _reply(200, _extraction()),
      ]);

      final result = await _extractor(server).extract(_url);

      expect(result.destination, 'Kyoto, Japan');
      expect(server.generateCalls, hasLength(2));
      // The second call went to a different model than the first.
      expect(
        server.generateCalls[0].url.path,
        isNot(server.generateCalls[1].url.path),
      );
      // And 404 is not retried against the same model.
      expect(server.generateCalls[0].url.path, contains('gemini-3.1-flash-lite'));
    });

    test('when no model works the message names what was tried', () async {
      final server = _Server(_withModelList([
        _reply(404, _errorBody(404, 'NOT_FOUND', 'model not found')),
      ]));

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>().having(
          (e) => e.message,
          'message',
          allOf(contains('GEMINI_MODEL'), contains('gemini-2.5-flash-lite')),
        )),
      );
    });
  });

  group('model choice', () {
    test('a retired id is never picked from a live list', () {
      final ranked = GeminiModels.rank([
        'gemini-2.0-flash',
        'gemini-3.1-flash-lite',
        'gemini-3.8-flash',
      ]);
      // 2.0-flash is dead, but ranking cannot know that — what it can do is
      // prefer the newest, which is the property that keeps this from rotting.
      expect(ranked.first, 'gemini-3.1-flash-lite');
      expect(ranked.indexOf('gemini-2.0-flash'), greaterThan(0));
    });

    test('flash-lite is preferred, then flash, then pro', () {
      expect(
        GeminiModels.rank([
          'gemini-2.5-pro',
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
        ]),
        ['gemini-2.5-flash-lite', 'gemini-2.5-flash', 'gemini-2.5-pro'],
      );
    });

    test('preview, experimental and non-text models are excluded', () {
      final ranked = GeminiModels.rank([
        'gemini-3.8-flash',
        'gemini-3.9-flash-preview-01-01',
        'gemini-2.0-flash-thinking-exp',
        'gemini-embedding-001',
        'imagen-4.0-generate-001',
        'gemini-2.5-flash-native-audio',
        'gemma-3-27b-it',
      ]);
      expect(ranked, ['gemini-3.8-flash']);
    });

    test('a plain id beats a suffixed one of the same version', () {
      expect(
        GeminiModels.rank(['gemini-3.1-flash-lite-001', 'gemini-3.1-flash-lite'])
            .first,
        'gemini-3.1-flash-lite',
      );
    });

    test('an explicit GEMINI_MODEL is used without listing the catalogue',
        () async {
      final server = _Server([_reply(200, _extraction())]);

      await _extractor(server, model: 'gemini-flash-latest').extract(_url);

      expect(
        server.generateCalls.single.url.path,
        contains('gemini-flash-latest'),
      );
      // Pinning a model is an answer, not a question: confirming it against the
      // catalogue would be a round trip whose result we would ignore.
      expect(server.requests.where((r) => r.url.path.endsWith('/models')),
          isEmpty);
    });

    test('a pinned model that no longer exists falls back to a real one',
        () async {
      final server = _Server([
        // The pinned id is gone...
        _reply(404, _errorBody(404, 'NOT_FOUND', 'model not found')),
        // ...so now the catalogue is worth asking for.
        _reply(200, _modelList),
        _reply(200, _extraction()),
      ]);

      final result =
          await _extractor(server, model: 'gemini-2.0-flash').extract(_url);

      expect(result.destination, 'Kyoto, Japan');
      expect(server.generateCalls.first.url.path, contains('gemini-2.0-flash'));
      expect(server.generateCalls.last.url.path,
          contains('gemini-2.5-flash-lite'));
    });

    test('a failed model list falls back to the rolling aliases', () async {
      final server = _Server([
        _reply(500, _errorBody(500, 'INTERNAL', 'nope')),
        _reply(500, _errorBody(500, 'INTERNAL', 'nope')),
        _reply(500, _errorBody(500, 'INTERNAL', 'nope')),
        _reply(500, _errorBody(500, 'INTERNAL', 'nope')),
        _reply(200, _extraction()),
      ]);

      final result = await _extractor(server).extract(_url);

      expect(result.destination, 'Kyoto, Japan');
      expect(
        server.generateCalls.single.url.path,
        contains(GeminiModels.fallback.first),
      );
    });
  });

  group('the request itself', () {
    test('carries the key, the schema and the URL being analysed', () async {
      final server = _Server(_withModelList([_reply(200, _extraction())]));

      await _extractor(server).extract(_url);

      final request = server.generateCalls.single;
      expect(request.headers['x-goog-api-key'], 'test-key');
      expect(request.method, 'POST');

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final config = body['generationConfig'] as Map<String, dynamic>;
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseSchema'], isA<Map>());
      expect(jsonEncode(body), contains('dQw4w9WgXcQ'));
    });

    test('the thumbnail is filled in from the link', () async {
      final server = _Server(_withModelList([_reply(200, _extraction())]));

      final result = await _extractor(server).extract(_url);

      expect(result.thumbnailUrl,
          'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    });

    test('coordinates outside the real ranges are dropped, not stored',
        () async {
      final server = _Server(_withModelList([
        _reply(
          200,
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'title': 'Somewhere',
                        'category': 'Other',
                        'latitude': 999,
                        'longitude': 12,
                      }),
                    },
                  ],
                },
              },
            ],
          }),
        ),
      ]));

      final result = await _extractor(server).extract(_url);
      expect(result.hasCoordinates, isFalse);
    });
  });

  group('no duplicate work', () {
    test('two analyses of the same link share one request', () async {
      final server = _Server(_withModelList([
        _reply(503, _overloaded),
        _reply(200, _extraction()),
      ]));
      final extractor = _extractor(server);

      final results = await Future.wait([
        extractor.extract(_url),
        extractor.extract(_url),
        extractor.extract(_url),
      ]);

      expect(results.map((r) => r.title).toSet(), hasLength(1));
      expect(server.generateCalls, hasLength(2),
          reason: 'one call plus its retry, not three calls plus three retries');
    });

    test('a second link after the first finishes does run', () async {
      final server = _Server(_withModelList([_reply(200, _extraction())]));
      final extractor = _extractor(server);

      await extractor.extract(_url);
      await extractor.extract('https://www.youtube.com/watch?v=abcdefghijk');

      expect(server.generateCalls, hasLength(2));
    });

    test('the model list is fetched once, not once per link', () async {
      final server = _Server(_withModelList([_reply(200, _extraction())]));
      final extractor = _extractor(server);

      await extractor.extract(_url);
      await extractor.extract('https://www.youtube.com/watch?v=abcdefghijk');

      final lists = server.requests
          .where((r) => r.url.path.endsWith('/models'))
          .toList();
      expect(lists, hasLength(1));
    });
  });

  group('it never hangs', () {
    test('a server that never answers ends in an error, not a spinner',
        () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 30));
        return http.Response('{}', 200);
      });
      final extractor = GeminiExtractor(
        apiKey: 'k',
        model: 'gemini-flash-latest',
        httpClient: client,
        retry: const RetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration(milliseconds: 5),
          attemptTimeout: Duration(milliseconds: 120),
          deadline: Duration(seconds: 2),
        ),
      );

      final started = DateTime.now();
      await expectLater(
        extractor.extract(_url),
        throwsA(isA<ExtractionException>()),
      );
      expect(DateTime.now().difference(started),
          lessThan(const Duration(seconds: 3)));
    });

    test('the deadline stops retries even when attempts remain', () async {
      final server = _Server(_withModelList([_reply(503, _overloaded)]));
      final extractor = GeminiExtractor(
        apiKey: 'k',
        model: 'gemini-flash-latest',
        httpClient: server.client,
        retry: const RetryPolicy(
          maxAttempts: 10,
          baseDelay: Duration(milliseconds: 60),
          maxDelay: Duration(milliseconds: 200),
          deadline: Duration(milliseconds: 400),
        ),
      );

      await expectLater(
        extractor.extract(_url),
        throwsA(isA<ExtractionException>()),
      );
      expect(server.generateCalls.length, lessThan(10));
    });
  });

  group('the stage messages tell the truth', () {
    test('a retry is announced to the screen', () async {
      final server = _Server(_withModelList([
        _reply(503, _overloaded),
        _reply(200, _extraction()),
      ]));
      final stages = <String>[];

      await _extractor(server).extract(_url, onStage: stages.add);

      expect(stages.first, 'Reading the link');
      expect(stages.any((s) => s.contains('busy')), isTrue);
      expect(stages.any((s) => s.contains('attempt 2 of 4')), isTrue);
      expect(stages.last, 'Reading the reply');
    });

    test('a joined duplicate is told so rather than shown a fresh spinner',
        () async {
      final server = _Server(_withModelList([_reply(200, _extraction())]));
      final extractor = _extractor(server);
      final stages = <String>[];

      final first = extractor.extract(_url);
      extractor.extract(_url, onStage: stages.add);
      await first;

      expect(stages, contains('Already analysing this link'));
    });
  });
}

/// A stand-in for the platform socket errors `package:http` surfaces, which
/// differ between web and IO. What matters is that it is not an HTTP response.
class SocketishException implements Exception {
  const SocketishException();
  @override
  String toString() => 'Connection reset by peer';
}
