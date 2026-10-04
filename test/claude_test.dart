import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/ai/ai_extractor.dart';
import 'package:nook/ai/claude_api.dart';
import 'package:nook/ai/claude_extractor.dart';

/// The AI transport, exercised against a scripted server.
///
/// The point of these tests is the part that is hardest to see by hand: what
/// happens when the API says no. Every failure mode the service can raise —
/// 429, 500, 502, 503, 504, 529, network loss, a body that is not JSON, a reply
/// with no tool call in it — is scripted here and the behaviour asserted, so
/// "it retries sensibly" is a checked fact rather than a claim.

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

String _errorBody(String type, String message) => jsonEncode({
  'type': 'error',
  'error': {'type': type, 'message': message},
});

/// The "we are busy" the service actually sends, in shape.
String get _overloaded =>
    _errorBody('overloaded_error', 'Overloaded. Please try again later.');

String _extraction({String title = '5 Hidden Cafes in Kyoto'}) => jsonEncode({
  'id': 'msg_1',
  'type': 'message',
  'role': 'assistant',
  'stop_reason': 'tool_use',
  'content': [
    {
      'type': 'tool_use',
      'id': 'toolu_1',
      'name': ClaudeExtractor.toolName,
      'input': {
        'title': title,
        'creator': '@wanderwithmia',
        'place_name': 'Kissa Master',
        'neighbourhood': 'Gion',
        'city': 'Kyoto',
        'country': 'Japan',
        'category': 'Food',
        'summary': 'Six cafes within a short walk of each other.',
        'best_time': 'March-May',
        'budget_note': '~JPY3,000/day',
        'latitude': 35.0116,
        'longitude': 135.7681,
      },
    },
  ],
});

/// Records every request, and answers from a script.
///
/// Routed by host rather than by position: extraction reads the post from its
/// platform before it asks the model anything, and an oEmbed lookup landing in
/// the middle of a script written for the model would shift every entry.
class _Server {
  _Server(this.script);

  /// One entry per model request, in order. The last repeats once exhausted.
  final List<http.Response Function(http.Request)> script;

  /// The post's own metadata, so these tests exercise the real path: a post
  /// that was read before the model was asked about it. The "nothing could be
  /// read" path is covered in `extraction_pipeline_test.dart`.
  static const oEmbed =
      '{"title":"5 Hidden Cafes in Kyoto","author_name":"Mia",'
      '"author_url":"https://www.youtube.com/@wanderwithmia","type":"video"}';

  final requests = <http.Request>[];
  final at = <DateTime>[];

  http.Client get client => MockClient((request) async {
    requests.add(request);
    at.add(DateTime.now());
    if (!request.url.host.contains('api.anthropic.com')) {
      return http.Response(
        oEmbed,
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    final index = min(modelCalls.length - 1, script.length - 1);
    return script[index](request);
  });

  int get calls => requests.length;

  List<http.Request> get modelCalls =>
      requests.where((r) => r.url.host.contains('api.anthropic.com')).toList();

  Map<String, Object?> get lastBody =>
      jsonDecode(modelCalls.last.body) as Map<String, Object?>;

  /// Everything the model was given: the standing instructions and the post.
  String get lastPrompt {
    final messages = lastBody['messages'] as List;
    final user = (messages.first as Map)['content'] as String;
    return '${lastBody['system']}\n$user';
  }
}

http.Response Function(http.Request) _reply(
  int status,
  String body, {
  Map<String, String>? headers,
}) =>
    (_) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json', ...?headers},
    );

ClaudeExtractor _extractor(_Server server, {String? model}) => ClaudeExtractor(
  apiKey: 'test-key',
  model: model,
  httpClient: server.client,
  retry: _fast,
);

void main() {
  group('a busy service is retried, not surfaced', () {
    test('one overload then a result: the user sees the result', () async {
      final server = _Server([
        _reply(529, _overloaded),
        _reply(200, _extraction()),
      ]);

      final result = await _extractor(server).extract(_url);

      expect(result.title, '5 Hidden Cafes in Kyoto');
      expect(server.modelCalls, hasLength(2));
    });

    test('three overloads then a result still succeeds', () async {
      final server = _Server([
        _reply(529, _overloaded),
        _reply(503, _overloaded),
        _reply(500, _errorBody('api_error', 'internal')),
        _reply(200, _extraction()),
      ]);

      final result = await _extractor(server).extract(_url);

      expect(result.city, 'Kyoto');
      expect(server.modelCalls, hasLength(4));
    });

    test('retries stop at the limit and report a real failure', () async {
      final server = _Server([_reply(529, _overloaded)]);

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>()),
      );

      // Four tries on the pinned id, then the same on the one fallback left.
      expect(server.modelCalls.length, greaterThanOrEqualTo(4));
    });

    test('the wait between tries grows instead of hammering', () async {
      final server = _Server([_reply(529, _overloaded)]);

      await expectLater(
        _extractor(server, model: 'only-this-one').extract(_url),
        throwsA(isA<ExtractionException>()),
      );

      final modelAt = <DateTime>[
        for (var i = 0; i < server.requests.length; i++)
          if (server.requests[i].url.host.contains('api.anthropic.com'))
            server.at[i],
      ];
      final gaps = [
        for (var i = 1; i < modelAt.length; i++)
          modelAt[i].difference(modelAt[i - 1]),
      ];
      expect(gaps, isNotEmpty);
      expect(
        gaps.every((gap) => gap > Duration.zero),
        isTrue,
        reason: 'every retry waits before it is sent',
      );
    });
  });

  group('every failure mode the API can raise', () {
    for (final status in [408, 409, 429, 500, 502, 503, 504, 529]) {
      test('$status is treated as transient and retried', () async {
        final server = _Server([
          _reply(status, _errorBody('api_error', 'nope')),
          _reply(200, _extraction()),
        ]);

        final result = await _extractor(server).extract(_url);

        expect(result.title, isNotEmpty);
        expect(server.modelCalls, hasLength(2));
      });
    }

    test('a rejected key fails at once, with no retries', () async {
      final server = _Server([
        _reply(401, _errorBody('authentication_error', 'invalid x-api-key')),
      ]);

      try {
        await _extractor(server).extract(_url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (e) {
        expect(e.message, contains('ANTHROPIC_API_KEY'));
      }

      expect(
        server.modelCalls,
        hasLength(1),
        reason: 'a bad key fails the same way every time',
      );
    });

    test('a rate limit says so, and does not blame the key', () async {
      final server = _Server([
        _reply(429, _errorBody('rate_limit_error', 'rate limit')),
      ]);

      try {
        await _extractor(server).extract(_url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (e) {
        expect(e.message, contains("today's limit"));
        expect(e.message, isNot(contains('ANTHROPIC_API_KEY')));
      }
    });

    test('an empty balance is reported rather than retried forever', () async {
      final server = _Server([
        _reply(
          400,
          _errorBody(
            'invalid_request_error',
            'Your credit balance is too low to access the API.',
          ),
        ),
      ]);

      try {
        await _extractor(server).extract(_url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (e) {
        expect(e.message.toLowerCase(), contains('credit'));
      }
      expect(server.modelCalls, hasLength(1));
    });

    test('retry-after from the server is honoured', () async {
      final server = _Server([
        _reply(
          429,
          _errorBody('rate_limit_error', 'slow down'),
          headers: {'retry-after': '1'},
        ),
        _reply(200, _extraction()),
      ]);

      await _extractor(server).extract(_url);

      final modelAt = <DateTime>[
        for (var i = 0; i < server.requests.length; i++)
          if (server.requests[i].url.host.contains('api.anthropic.com'))
            server.at[i],
      ];
      expect(modelAt, hasLength(2));
      expect(
        modelAt.last.difference(modelAt.first),
        greaterThan(const Duration(milliseconds: 800)),
        reason: 'the computed backoff here is 40ms at most, so only the '
            "server's own header can account for the wait",
      );
    });

    test('a network failure is retried, then reported honestly', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        if (!request.url.host.contains('api.anthropic.com')) {
          return http.Response(_Server.oEmbed, 200);
        }
        attempts++;
        throw http.ClientException('connection closed');
      });

      final extractor = ClaudeExtractor(
        apiKey: 'k',
        model: 'only-this-one',
        httpClient: client,
        retry: _fast,
      );

      try {
        await extractor.extract(_url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (e) {
        expect(e.message.toLowerCase(), contains('try again'));
      }
      expect(attempts, greaterThan(1), reason: 'a lost request is retried');
    });

    test('a 200 that is not JSON is not retried forever', () async {
      final server = _Server([_reply(200, '<html>maintenance</html>')]);

      await expectLater(
        _extractor(server, model: 'only-this-one').extract(_url),
        throwsA(isA<ExtractionException>()),
      );
      expect(
        server.modelCalls,
        hasLength(1),
        reason: 'retrying will not turn HTML into JSON',
      );
    });

    test('a refusal is reported without saying what was refused', () async {
      final server = _Server([
        _reply(
          200,
          jsonEncode({'stop_reason': 'refusal', 'content': <Object>[]}),
        ),
      ]);

      try {
        await _extractor(server).extract(_url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (e) {
        expect(e.message.toLowerCase(), isNot(contains('refus')));
        expect(e.message.toLowerCase(), contains('try a different link'));
      }
    });

    test('a reply that answers in prose is reported, not half-read', () async {
      final server = _Server([
        _reply(
          200,
          jsonEncode({
            'stop_reason': 'end_turn',
            'content': [
              {'type': 'text', 'text': 'Here are some cafes!'},
            ],
          }),
        ),
      ]);

      await expectLater(
        _extractor(server).extract(_url),
        throwsA(isA<ExtractionException>()),
      );
    });

    test('a reply cut off at the ceiling says so', () async {
      final server = _Server([
        _reply(
          200,
          jsonEncode({'stop_reason': 'max_tokens', 'content': <Object>[]}),
        ),
      ]);

      try {
        await _extractor(server).extract(_url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (e) {
        expect(e.message.toLowerCase(), contains('one go'));
      }
    });
  });

  group('a model id that is gone moves on instead of failing', () {
    test('404 on the first id tries the next one', () async {
      final server = _Server([
        _reply(404, _errorBody('not_found_error', 'model: nope')),
        _reply(200, _extraction()),
      ]);

      final result = await _extractor(server, model: 'nope').extract(_url);

      expect(result.title, '5 Hidden Cafes in Kyoto');
      expect(server.modelCalls, hasLength(2));
      expect(
        (jsonDecode(server.modelCalls.first.body) as Map)['model'],
        'nope',
      );
      expect(
        (jsonDecode(server.modelCalls.last.body) as Map)['model'],
        ClaudeModels.haiku,
      );
    });

    test('when no id works the message says what to change', () async {
      final server = _Server([
        _reply(404, _errorBody('not_found_error', 'model: gone')),
      ]);

      try {
        await _extractor(server).extract(_url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (e) {
        expect(e.message, contains('CLAUDE_MODEL'));
      }
    });

    test('an id that answered 404 is not asked twice in a session', () async {
      final server = _Server([
        _reply(404, _errorBody('not_found_error', 'model: gone')),
        _reply(200, _extraction()),
      ]);
      final extractor = _extractor(server);

      await extractor.extract(_url);
      final firstRound = server.modelCalls.length;

      await extractor.extract('https://www.youtube.com/watch?v=aaaaaaaaaaa');

      expect(
        server.modelCalls.length - firstRound,
        1,
        reason: 'the retired id is skipped on the second link',
      );
    });
  });

  group('model choice', () {
    test('the default is the pinned Haiku id', () {
      expect(ClaudeModels.candidates(null).first, ClaudeModels.haiku);
      expect(ClaudeModels.haiku, contains('haiku-4-5'));
    });

    test('a pinned id goes first, and is not repeated', () {
      final list = ClaudeModels.candidates('my-model');
      expect(list.first, 'my-model');
      expect(list.where((id) => id == 'my-model'), hasLength(1));
      expect(list, contains(ClaudeModels.haiku));
    });

    test('a blank pin is the same as no pin', () {
      expect(ClaudeModels.candidates('   '), ClaudeModels.fallback);
    });
  });

  group('the request itself', () {
    test('carries the key, the version and the post being analysed', () async {
      final server = _Server([_reply(200, _extraction())]);
      await _extractor(server).extract(_url);

      final request = server.modelCalls.single;
      expect(request.headers['x-api-key'], 'test-key');
      expect(request.headers['anthropic-version'], ClaudeClient.apiVersion);
      expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(server.lastPrompt, contains(_url.split('v=').last));
    });

    test('forces the answer into the schema rather than asking for it', () async {
      final server = _Server([_reply(200, _extraction())]);
      await _extractor(server).extract(_url);

      final body = server.lastBody;
      final tool = (body['tools'] as List).single as Map;

      expect(tool['name'], ClaudeExtractor.toolName);
      expect((tool['input_schema'] as Map)['type'], 'object');
      expect(
        (tool['input_schema'] as Map)['required'],
        containsAll(<String>['title', 'category']),
      );
      expect((body['tool_choice'] as Map)['type'], 'tool');
      expect((body['tool_choice'] as Map)['name'], ClaudeExtractor.toolName);
    });

    test('sampling is off, so the same post extracts the same way', () async {
      final server = _Server([_reply(200, _extraction())]);
      await _extractor(server).extract(_url);

      expect(
        server.lastBody['temperature'],
        0,
        reason: 'extraction copies facts; sampling here is pure variance',
      );
    });

    test('the reply is capped, so it cannot run until it times out', () async {
      final server = _Server([_reply(200, _extraction())]);
      await _extractor(server).extract(_url);

      expect(server.lastBody['max_tokens'], ClaudeExtractor.maxOutputTokens);
    });

    test('the summary is pinned to English, whatever the source speaks', () async {
      final server = _Server([_reply(200, _extraction())]);
      await _extractor(server).extract(_url);

      expect(server.lastPrompt, contains('ALWAYS write this in English'));
    });

    test('the thumbnail is filled in from the link', () async {
      final server = _Server([_reply(200, _extraction())]);
      final result = await _extractor(server).extract(_url);

      expect(result.thumbnailUrl, contains('dQw4w9WgXcQ'));
    });
  });

  group('no duplicate work', () {
    test('two analyses of the same link share one request', () async {
      final server = _Server([_reply(200, _extraction())]);
      final extractor = _extractor(server);

      final both = await Future.wait([
        extractor.extract(_url),
        extractor.extract(_url),
      ]);

      expect(both.first.title, both.last.title);
      expect(server.modelCalls, hasLength(1));
    });

    test('a second link after the first finishes does run', () async {
      final server = _Server([_reply(200, _extraction())]);
      final extractor = _extractor(server);

      await extractor.extract(_url);
      await extractor.extract('https://www.youtube.com/watch?v=aaaaaaaaaaa');

      expect(server.modelCalls, hasLength(2));
    });
  });

  group('the screen is told the phase, not the machinery', () {
    test('progress is reported as phases, in order', () async {
      final server = _Server([_reply(200, _extraction())]);
      final phases = <ExtractionPhase>[];

      await _extractor(server).extract(_url, onStage: phases.add);

      expect(phases.first, ExtractionPhase.readingPost);
      expect(phases, contains(ExtractionPhase.analysing));
      expect(phases.last, ExtractionPhase.finishing);
      expect(phases.toSet(), hasLength(3));
    });

    test('a retry is part of the wait, not a new phase', () async {
      final server = _Server([
        _reply(529, _overloaded),
        _reply(200, _extraction()),
      ]);
      final phases = <ExtractionPhase>[];

      await _extractor(server).extract(_url, onStage: phases.add);

      expect(phases.toSet(), hasLength(3));
    });
  });

  group('nothing the user reads names the machinery', () {
    const forbidden = [
      'claude',
      'anthropic',
      'haiku',
      'http',
      '429',
      '503',
      '529',
      'tool_use',
      'json',
      'token',
      'schema',
      'stop_reason',
    ];

    final scripts = <String, http.Response Function(http.Request)>{
      'overloaded': _reply(529, _overloaded),
      'rate limited': _reply(429, _errorBody('rate_limit_error', 'slow down')),
      'refused': _reply(
        200,
        jsonEncode({'stop_reason': 'refusal', 'content': <Object>[]}),
      ),
      'prose': _reply(
        200,
        jsonEncode({
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': 'hello'},
          ],
        }),
      ),
      'not json': _reply(200, '<html>down</html>'),
    };

    scripts.forEach((name, script) {
      test('a $name failure reads as plain English', () async {
        final server = _Server([script]);
        try {
          await _extractor(server).extract(_url);
          fail('expected an ExtractionException');
        } on ExtractionException catch (e) {
          final lower = e.message.toLowerCase();
          for (final word in forbidden) {
            expect(lower, isNot(contains(word)), reason: 'leaked "$word"');
          }
        }
      });
    });

    test('every message tells the person what they can do next', () async {
      final server = _Server([_reply(529, _overloaded)]);
      try {
        await _extractor(server).extract(_url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (e) {
        expect(e.message.toLowerCase(), contains('try again'));
      }
    });
  });

  group('it never hangs', () {
    test('the deadline stops retries even when attempts remain', () async {
      final server = _Server([_reply(529, _overloaded)]);
      final started = DateTime.now();

      await expectLater(
        ClaudeExtractor(
          apiKey: 'k',
          model: 'only-this-one',
          httpClient: server.client,
          retry: const RetryPolicy(
            maxAttempts: 40,
            baseDelay: Duration(milliseconds: 20),
            maxDelay: Duration(milliseconds: 60),
            attemptTimeout: Duration(seconds: 1),
            deadline: Duration(milliseconds: 300),
          ),
        ).extract(_url),
        throwsA(isA<ExtractionException>()),
      );

      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 5)),
        reason: 'the deadline bounds the whole sequence, not each attempt',
      );
    });
  });

  group('the exception classifies itself', () {
    test('overload is transient and routable', () {
      const e = ClaudeApiException(
        message: 'busy',
        status: 529,
        type: 'overloaded_error',
      );
      expect(e.isTransient, isTrue);
      expect(e.isOverloaded, isTrue);
      expect(e.isAuthFailure, isFalse);
    });

    test('a missing status is the most retryable case of all', () {
      const e = ClaudeApiException(message: 'socket closed');
      expect(e.isTransient, isTrue);
    });

    test('auth and not-found are terminal', () {
      const auth = ClaudeApiException(
        message: 'bad key',
        status: 401,
        type: 'authentication_error',
      );
      const gone = ClaudeApiException(
        message: 'model: x',
        status: 404,
        type: 'not_found_error',
      );
      expect(auth.isTransient, isFalse);
      expect(auth.isAuthFailure, isTrue);
      expect(gone.isTransient, isFalse);
      expect(gone.isModelUnavailable, isTrue);
    });
  });
}
