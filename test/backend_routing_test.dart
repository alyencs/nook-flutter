import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/ai/claude_api.dart';
import 'package:nook/ai/ai_extractor.dart';
import 'package:nook/ai/claude_extractor.dart';
import 'package:nook/ai/claude_itinerary_generator.dart';
import 'package:nook/ai/itinerary_generator.dart';

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

    test('it goes to the service, not to the API, and asks for /v1/messages', () async {
      final r = recorder();
      final request = await callWith(
        ClaudeClient(baseUrl: 'https://nook-ai.example.workers.dev', httpClient: r.client),
        r.sent,
      );

      // This assertion used to read `/messages`, which is what shipped and
      // what every deployed call 404'd on: the service serves `/v1/messages`
      // and nothing compared the two sides. The `/v1` had been folded into
      // `anthropicBase`, so pointing the client at a backend replaced it.
      expect(
        request.url.toString(),
        'https://nook-ai.example.workers.dev/v1/messages',
      );
      expect(request.url.host, isNot('api.anthropic.com'));
    });

    test('the address may be configured with or without the /v1', () async {
      // NOOK_AI_BACKEND is typed into a repository variable by hand, so both
      // spellings turn up. Neither may 404, and neither may produce /v1/v1.
      for (final configured in [
        'https://nook-ai.example.workers.dev',
        'https://nook-ai.example.workers.dev/',
        'https://nook-ai.example.workers.dev/v1',
        'https://nook-ai.example.workers.dev/v1/',
      ]) {
        final r = recorder();
        final request = await callWith(
          ClaudeClient(baseUrl: configured, httpClient: r.client),
          r.sent,
        );

        expect(
          request.url.toString(),
          'https://nook-ai.example.workers.dev/v1/messages',
          reason: 'configured as "$configured"',
        );
      }
    });

    test('the path it asks for is the one the service publishes', () {
      // The contract file is the single source of truth, read here and by
      // server/test/contract.test.mjs. If either side moves, one of those two
      // tests fails rather than the deployed app 404ing quietly.
      final contract =
          jsonDecode(File('server/api-contract.json').readAsStringSync())
              as Map<String, Object?>;

      expect('/${ClaudeClient.messagesPath}', contract['messagesPath']);
      expect(contract['method'], 'POST');
    });

    test('the operations it names are the ones the service offers', () {
      // The second half of the same failure. The path was wrong, and so was
      // the extraction tool name: the app sent `record_post_details` while
      // every server-side copy said `record_extraction`, so once the path was
      // fixed extraction would have been refused with a 400 instead — a
      // different error, the same afternoon lost. The service offers exactly
      // two operations and refuses anything else, which is what keeps the
      // published address from being a free chat endpoint, so the names have
      // to agree to the character.
      final contract =
          jsonDecode(File('server/api-contract.json').readAsStringSync())
              as Map<String, Object?>;
      final tools = (contract['tools'] as List).cast<String>();

      expect(tools, contains(ClaudeExtractor.toolName));
      expect(tools, contains(ClaudeItineraryGenerator.toolName));
      expect(
        tools,
        hasLength(2),
        reason: 'two operations, and the allowlist is the anti-abuse control',
      );
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

  group('when the service does not serve the path asked for', () {
    // The deployed failure, reproduced: a service that is up and healthy,
    // answering 404 because the path it was asked for is not the path it
    // serves. What the person was told about it mattered as much as the bug —
    // the message named CLAUDE_MODEL, so the search went to the model
    // configuration and stayed there.
    const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
    const backend = 'https://nook-ai.example.workers.dev';

    /// Answers oEmbed for the platform and a routing 404 for the service.
    ({List<http.Request> toBackend, http.Client client}) refusing(
      String errorMessage,
    ) {
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
            'error': {'type': 'not_found_error', 'message': errorMessage},
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });
      return (toBackend: toBackend, client: client);
    }

    test('the extractor names the address, not the model setting', () async {
      final r = refusing(
        'Unknown endpoint: POST /messages. This service serves POST '
        '/v1/messages and GET /health.',
      );

      try {
        await ClaudeExtractor(backendUrl: backend, httpClient: r.client)
            .extract(url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (e) {
        expect(e.message, contains('AI_BACKEND_URL'));
        expect(
          e.message,
          isNot(contains('CLAUDE_MODEL')),
          reason: 'the model setting was never the problem and saying so cost '
              'a day',
        );
      }
    });

    test('it stops at the first refusal instead of working the model list',
        () async {
      final r = refusing('Unknown endpoint.');

      try {
        await ClaudeExtractor(backendUrl: backend, httpClient: r.client)
            .extract(url);
        fail('expected an ExtractionException');
      } on ExtractionException catch (_) {
        // The message is asserted above; this test is about the call count.
      }

      // Counted on the model route alone. The extractor also asks the service
      // to read the post first, which is a different route and a different
      // failure, so counting every backend request would pass or fail here for
      // the wrong reason.
      final modelCalls = r.toBackend.where(
        (request) => request.url.path.endsWith('/v1/messages'),
      );
      expect(
        modelCalls,
        hasLength(1),
        reason: 'every candidate fails identically, so trying them all only '
            'retires the list and buries the cause',
      );
    });

    test('the planner reports it the same way', () async {
      final r = refusing('Unknown endpoint.');
      final planner = ClaudeItineraryGenerator(
        backendUrl: backend,
        httpClient: r.client,
      );

      try {
        await planner.generate(
          const ItineraryRequest(
            destination: 'Kyoto, Japan',
            days: 3,
            // Enough detail to get past the "nothing saved yet" guard, so the
            // request actually reaches the service and the 404 is what fails.
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

      expect(
        r.toBackend.where(
          (request) => request.url.path.endsWith('/v1/messages'),
        ),
        hasLength(1),
      );
    });
  });
}
