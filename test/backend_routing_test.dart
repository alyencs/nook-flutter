import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/ai/claude_api.dart';
import 'package:nook/ai/claude_extractor.dart';
import 'package:nook/ai/claude_itinerary_generator.dart';

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

      expect(request.url.toString(), 'https://nook-ai.example.workers.dev/messages');
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
}
