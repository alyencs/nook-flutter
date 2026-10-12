import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/ai/ai_extractor.dart';
import 'package:nook/ai/claude_api.dart';
import 'package:nook/ai/claude_extractor.dart';
import 'package:nook/ai/claude_itinerary_generator.dart';
import 'package:nook/ai/itinerary_generator.dart';
import 'package:nook/ai/source_metadata.dart';

/// Where the request goes, and what it carries when it gets there.
///
/// The thing that must never happen is a published build with a key in it.
/// That is not something a reader can confirm by eye once the call is five
/// files deep, so it is pinned here instead: pointed at the service, the
/// request leaves with no credential of any kind on it.
void main() {
  /// Captures one request and answers with an empty, well-formed message.
  ({List<http.Request> sent, http.Client client}) recorder() {
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      return http.Response(
        jsonEncode({
          'id': 'msg_test',
          'type': 'message',
          'content': <Object>[],
          'stop_reason': 'end_turn',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    return (sent: sent, client: client);
  }

  Future<http.Request> callWith(ClaudeClient client, List<http.Request> sent) async {
    await client.createMessage(
      body: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 64,
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
      },
    );
    expect(sent, hasLength(1));
    return sent.single;
  }

  group('pointed at the service', () {
    test('the request carries no credential', () async {
      final r = recorder();
      final request = await callWith(
        ClaudeClient(baseUrl: 'https://nook-ai.example.workers.dev', httpClient: r.client),
        r.sent,
      );

      expect(request.headers.keys.map((k) => k.toLowerCase()), isNot(contains('x-api-key')));
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('anthropic-dangerous-direct-browser-access')),
        reason: 'that header only belongs on a call the client makes itself',
      );
    });

    test('it goes to the service, not to the API', () async {
      final r = recorder();
      final request = await callWith(
        ClaudeClient(baseUrl: 'https://nook-ai.example.workers.dev', httpClient: r.client),
        r.sent,
      );

      // The host is what this test is about. The path is /v1/messages because
      // that is the only path the service answers on, and a bare host in the
      // setting is completed rather than sent somewhere that returns 404.
      expect(
        request.url.toString(),
        'https://nook-ai.example.workers.dev/v1/messages',
      );
      expect(request.url.host, isNot('api.anthropic.com'));
    });

    test('a trailing slash on the configured address is not doubled', () async {
      final r = recorder();
      final request = await callWith(
        ClaudeClient(baseUrl: 'https://nook-ai.example.workers.dev/v1/', httpClient: r.client),
        r.sent,
      );

      expect(request.url.toString(), 'https://nook-ai.example.workers.dev/v1/messages');
    });

    test('the body is unchanged by the detour', () async {
      final r = recorder();
      final request = await callWith(
        ClaudeClient(baseUrl: 'https://nook-ai.example.workers.dev', httpClient: r.client),
        r.sent,
      );

      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['model'], 'claude-haiku-4-5-20251001');
      expect(body['max_tokens'], 64);
      expect(body['messages'], hasLength(1));
    });

    test('it reports that it is not the one holding a key', () {
      final client = ClaudeClient(baseUrl: 'https://nook-ai.example.workers.dev');
      expect(client.sendsKeyDirectly, isFalse);
      client.close();
    });
  });

  group('pointed at the API directly', () {
    test('the key is sent, which is what makes it the local-only path', () async {
      final r = recorder();
      final request = await callWith(
        ClaudeClient(apiKey: 'local-only-key', httpClient: r.client),
        r.sent,
      );

      expect(request.headers['x-api-key'], 'local-only-key');
      expect(request.url.host, 'api.anthropic.com');
    });

    test('it reports that it is holding one', () {
      final client = ClaudeClient(apiKey: 'local-only-key');
      expect(client.sendsKeyDirectly, isTrue);
      client.close();
    });
  });

  group('the two generators route the same way', () {
    test('the extractor reaches the service with no credential', () async {
      final r = recorder();
      final extractor = ClaudeExtractor(
        backendUrl: 'https://nook-ai.example.workers.dev',
        httpClient: r.client,
      );

      // The result does not matter here; where the request went does.
      try {
        await extractor.extract('https://www.tiktok.com/@a/video/1');
      } catch (_) {
        // The stubbed answer carries no tool call, so parsing it fails. That
        // is fine: the request has already been sent and recorded.
      }

      final toService = r.sent.where(
        (request) => request.url.host == 'nook-ai.example.workers.dev',
      );
      expect(toService, isNotEmpty, reason: 'the model call went to the service');
      for (final request in toService) {
        expect(request.headers.keys.map((k) => k.toLowerCase()), isNot(contains('x-api-key')));
      }
    });

    test('the planner takes a backend too', () {
      final planner = ClaudeItineraryGenerator(
        backendUrl: 'https://nook-ai.example.workers.dev',
      );
      expect(planner, isNotNull);
    });
  });

  group('the address as a deployment actually types it', () {
    /// This value is written by hand into a repository variable or an env
    /// file, and it is written wrong in predictable ways. A missing scheme is
    /// the expensive one: `nook-ai.example.workers.dev/v1` reads to `Uri` as a
    /// path with no host, so the request fails before it is sent and the only
    /// thing the screen can say is that the service could not be reached —
    /// which sends someone to check a network that was never the problem.
    Future<String> urlFor(String base) async {
      var seen = '(never sent)';
      final client = MockClient((request) async {
        seen = request.url.toString();
        return http.Response(
          jsonEncode({'id': 'msg', 'type': 'message', 'content': <Object>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final subject = ClaudeClient(
        baseUrl: base,
        httpClient: client,
        retry: const RetryPolicy(maxAttempts: 1),
      );
      try {
        await subject.createMessage(
          body: {'model': 'm', 'max_tokens': 1, 'messages': const []},
        );
      } on ClaudeApiException catch (e) {
        seen = e.isMisconfigured ? 'refused' : 'error ${e.status}';
      }
      subject.close();
      return seen;
    }

    const endpoint = 'https://nook-ai.example.workers.dev/v1/messages';

    test('a correctly written address reaches /v1/messages', () async {
      expect(await urlFor('https://nook-ai.example.workers.dev/v1'), endpoint);
    });

    test('an address with no scheme is still used, not abandoned', () async {
      expect(await urlFor('nook-ai.example.workers.dev/v1'), endpoint);
    });

    test('whitespace around the address is ignored', () async {
      expect(
        await urlFor('  https://nook-ai.example.workers.dev/v1  '),
        endpoint,
      );
    });

    test('a trailing slash does not double the one before messages', () async {
      expect(await urlFor('https://nook-ai.example.workers.dev/v1/'), endpoint);
    });

    test('/v1 appears exactly once, never twice', () async {
      final url = await urlFor('https://nook-ai.example.workers.dev/v1');
      expect('/v1'.allMatches(url).length, 1);
    });

    test('an address with nothing in it is refused, not sent', () async {
      for (final blank in ['', '   ']) {
        expect(
          await urlFor(blank),
          'refused',
          reason: 'nothing can be requested, and the message must say so',
        );
      }
    });

    test('a misconfigured address is not reported as a dead network', () {
      const misconfigured = ClaudeApiException(
        type: ClaudeClient.configurationErrorType,
        message: 'The AI service address is not a usable web address: "".',
      );

      expect(misconfigured.isMisconfigured, isTrue);
      expect(
        misconfigured.isUnreachable,
        isTrue,
        reason: 'it never reached a server either — but the cause is a setting',
      );
    });

    test("the service's own 404 is not read as a missing model", () {
      // Nook's service answers an unknown path this way. Anthropic's "no such
      // model" 404 names the model; this one does not, and telling someone to
      // check CLAUDE_MODEL when the address is missing its /v1 sends them to
      // the wrong file.
      const unknownEndpoint = ClaudeApiException(
        status: 404,
        type: 'not_found_error',
        message: 'Unknown endpoint.',
      );
      const goneModel = ClaudeApiException(
        status: 404,
        type: 'not_found_error',
        message: 'model: claude-x not found',
      );

      expect(unknownEndpoint.isModelUnavailable, isFalse);
      expect(goneModel.isModelUnavailable, isTrue);
    });
  });

  group('the address, however it was written into the setting', () {
    /// Only one path on the service answers: `/v1/messages`. Everything else
    /// is a 404, and a 404 reads to someone using the app as the AI being
    /// broken rather than a setting being one segment out.
    ///
    /// Three ways people land on a wrong one, all of them reasonable. Pasting
    /// the endpoint from the documentation, which names the full URL, into a
    /// setting that wants the base. Pasting the host on its own. And being
    /// told to make sure the address ends in /v1 when it already did.
    Future<String> urlFor(String base) async {
      var seen = '(never sent)';
      final client = MockClient((request) async {
        seen = request.url.toString();
        return http.Response(
          jsonEncode({'id': 'msg', 'type': 'message', 'content': <Object>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final subject = ClaudeClient(
        baseUrl: base,
        httpClient: client,
        retry: const RetryPolicy(maxAttempts: 1),
      );
      try {
        await subject.createMessage(
          body: {'model': 'm', 'max_tokens': 1, 'messages': const []},
        );
      } on ClaudeApiException catch (e) {
        seen = e.isMisconfigured ? 'refused' : 'error ${e.status}';
      }
      subject.close();
      return seen;
    }

    const host = 'https://nook-ai.example.workers.dev';
    const endpoint = '$host/v1/messages';

    test('every ordinary way of writing it reaches the one endpoint', () async {
      for (final written in [
        '$host/v1', // as documented
        host, // the host on its own
        '$host/v1/messages', // the full endpoint pasted into the base
        '$host/v1/v1', // /v1 added to an address that had it
        '$host/v1/v1/v1', // and added twice
        '$host/messages', // the method without the version
        '$host/v1/', // a trailing slash
        '  $host/v1  ', // whitespace from a copy and paste
        'nook-ai.example.workers.dev/v1', // no scheme
        'nook-ai.example.workers.dev/v1/messages', // neither scheme nor base
      ]) {
        expect(await urlFor(written), endpoint, reason: 'from "$written"');
      }
    });

    test('/v1 is present exactly once, never twice', () async {
      for (final written in ['$host/v1/v1', '$host/v1', host]) {
        final url = await urlFor(written);
        expect('/v1'.allMatches(url).length, 1, reason: 'from "$written"');
      }
    });

    test('messages is appended once, never doubled', () async {
      final url = await urlFor('$host/v1/messages');
      expect('messages'.allMatches(url).length, 1);
    });

    test('calling the API directly still resolves the same way', () async {
      expect(
        await urlFor('https://api.anthropic.com'),
        'https://api.anthropic.com/v1/messages',
      );
      expect(
        await urlFor('https://api.anthropic.com/v1'),
        'https://api.anthropic.com/v1/messages',
      );
    });

    test('a path that says something else is left as it was meant', () async {
      // Only an empty path is filled in. Someone who put the service behind a
      // prefix of their own meant it, and guessing over them would be worse
      // than the 404 they would get for a genuine mistake.
      expect(await urlFor('$host/api'), '$host/api/messages');
    });

    test('an address with nothing usable in it is still refused', () async {
      for (final written in ['', '   ']) {
        expect(await urlFor(written), 'refused');
      }
    });
  });

  group('the contract the app and the service share', contractTests);

  group('when the service serves nothing at the address', routingFailureTests);
}

/// The service's two routes, pinned against the contract file.
///
/// `server/api-contract.json` is read here and by `server/test/contract.test.mjs`,
/// so the app and the service cannot drift apart without one of the two suites
/// going red. That is the gap the original fault fell through: the Dart tests
/// asserted the path the app asked for, the Node tests built their own request
/// at the path the service served, both passed, and every deployed call
/// returned `404 not_found_error`.
void contractTests() {
  Map<String, Object?> contract() =>
      jsonDecode(File('server/api-contract.json').readAsStringSync())
          as Map<String, Object?>;

  test('the model route is the one the service publishes', () async {
    var seen = '';
    final client = MockClient((request) async {
      seen = request.url.path;
      return http.Response(
        jsonEncode({'id': 'm', 'type': 'message', 'content': <Object>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final subject = ClaudeClient(
      baseUrl: 'https://nook-ai.example.workers.dev/v1',
      httpClient: client,
    );
    await subject.createMessage(
      body: {'model': 'm', 'max_tokens': 1, 'messages': const []},
    );
    subject.close();

    expect(seen, contract()['messagesPath']);
    expect(contract()['method'], 'POST');
  });

  test('the metadata route is the one the service publishes', () {
    expect(
      '/${SourceMetadataFetcher.metadataPath}',
      contract()['metadataPath'],
    );
  });

  test('the operations named are the ones the service offers', () {
    // The other half of the same drift. The app sent `record_post_details`
    // while every server-side copy said `record_extraction`, so once the path
    // was right extraction would have been refused with a 400 instead.
    final tools = (contract()['tools'] as List).cast<String>();

    expect(tools, contains(ClaudeExtractor.toolName));
    expect(tools, contains(ClaudeItineraryGenerator.toolName));
    expect(tools, hasLength(2));
  });
}

/// What the person is told when the address serves nothing, and what the app
/// does about it.
void routingFailureTests() {
  const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  const backend = 'https://nook-ai.example.workers.dev/v1';

  /// Answers every service route with a 404, and the platform with oEmbed.
  ({List<http.Request> toBackend, http.Client client}) refusing() {
    final toBackend = <http.Request>[];
    final client = MockClient((request) async {
      if (!request.url.host.contains('nook-ai.example.workers.dev')) {
        return http.Response(
          '{"title":"5 Hidden Cafes in Kyoto","author_name":"Mia",'
          '"type":"video"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      toBackend.add(request);
      return http.Response(
        jsonEncode({
          'type': 'error',
          'error': {'type': 'not_found_error', 'message': 'Unknown endpoint.'},
        }),
        404,
        headers: {'content-type': 'application/json'},
      );
    });
    return (toBackend: toBackend, client: client);
  }

  /// Model calls only. The extractor also asks the service to read the post,
  /// which is a different route and a different failure.
  Iterable<http.Request> modelCalls(List<http.Request> all) =>
      all.where((request) => request.url.path.endsWith('/v1/messages'));

  test('the extractor names the address, not the model setting', () async {
    final r = refusing();

    try {
      await ClaudeExtractor(backendUrl: backend, httpClient: r.client)
          .extract(url);
      fail('expected an ExtractionException');
    } on ExtractionException catch (e) {
      expect(e.message, contains('AI_BACKEND_URL'));
      expect(
        e.message,
        isNot(contains('CLAUDE_MODEL')),
        reason: 'the model setting was never the problem, and saying it was '
            'sent the search to the wrong file',
      );
    }
  });

  test('it stops at the first refusal instead of working the model list', () async {
    final r = refusing();

    try {
      await ClaudeExtractor(backendUrl: backend, httpClient: r.client)
          .extract(url);
      fail('expected an ExtractionException');
    } on ExtractionException catch (_) {
      // The message is asserted above; this is about the call count.
    }

    expect(
      modelCalls(r.toBackend),
      hasLength(1),
      reason: 'every candidate fails identically, so working through them only '
          'retires the list and buries the cause',
    );
  });

  test('the planner reports it the same way', () async {
    final r = refusing();
    final planner = ClaudeItineraryGenerator(
      backendUrl: backend,
      httpClient: r.client,
    );

    try {
      await planner.generate(
        const ItineraryRequest(
          destination: 'Kyoto, Japan',
          days: 3,
          // Enough detail to clear the "nothing saved yet" guard, so the
          // request reaches the service and the 404 is what fails.
          sources: [
            ItinerarySource(
              title: '5 Hidden Cafes in Kyoto',
              city: 'Kyoto',
              country: 'Japan',
              summary: 'Six cafes within a short walk of each other.',
            ),
          ],
        ),
      );
      fail('expected an ItineraryException');
    } on ItineraryException catch (e) {
      expect(e.message, contains('AI_BACKEND_URL'));
      expect(e.message, isNot(contains('CLAUDE_MODEL')));
    }

    expect(modelCalls(r.toBackend), hasLength(1));
  });
}
