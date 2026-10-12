// A real request, over a real socket, against a service that is actually
// listening.
//
// Everything in `test/` answers from a `MockClient`. That proves what the
// client asks for, and it is how the routing bug survived: the Dart tests
// asserted `/messages` and passed, the service's tests built their own request
// at `/v1/messages` and passed, and no test ever put the two in the same room.
// Every deployed call returned `404 not_found_error`.
//
// This file is that room. It points the unmodified `ClaudeClient` at a running
// service and reads what comes back, so the path the client builds and the path
// the service serves have to meet for it to pass.
//
// Not part of `flutter test` — it needs something listening, so it is run on
// purpose:
//
//   node server/test/serve_local.mjs &            # the stub, nothing spent
//   flutter test tool/live_check.dart
//
//   NOOK_AI_BACKEND=https://your-service.workers.dev \
//     flutter test tool/live_check.dart            # the real one, real tokens
//
// See "Verifying the AI path" in server/README.md.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:nook/ai/ai_extractor.dart';
import 'package:nook/ai/claude_api.dart';
import 'package:nook/ai/claude_extractor.dart';
import 'package:nook/ai/claude_itinerary_generator.dart';
import 'package:nook/ai/source_metadata.dart';

/// Where to knock. The stub unless told otherwise.
final _base = Platform.environment['NOOK_AI_BACKEND']?.trim().isNotEmpty == true
    ? Platform.environment['NOOK_AI_BACKEND']!.trim()
    : 'http://127.0.0.1:8787';

final _model = Platform.environment['CLAUDE_MODEL']?.trim().isNotEmpty == true
    ? Platform.environment['CLAUDE_MODEL']!.trim()
    : 'claude-haiku-4-5-20251001';

/// A request in the shape the app sends one, naming a contracted operation.
Map<String, Object?> _body(String tool) => {
  'model': _model,
  'max_tokens': 512,
  'messages': [
    {
      'role': 'user',
      'content': 'A post titled "5 Hidden Cafes in Kyoto" by @wanderwithmia, '
          'about Kissa Master in the Gion district of Kyoto, Japan. '
          'Record what it is about.',
    },
  ],
  'tools': [
    {
      'name': tool,
      'description': 'Record the result of reading the post.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'city': {'type': 'string'},
          'country': {'type': 'string'},
        },
        'required': ['title'],
      },
    },
  ],
  'tool_choice': {'type': 'tool', 'name': tool},
};

void main() {
  // flutter_test replaces dart:io networking with a stub that fails every
  // request. These tests are about the network, so hand it back.
  setUp(() => HttpOverrides.global = null);

  tearDown(() => HttpOverrides.global = null);

  test('the service answers a real request at the path the client asks for', () async {
    final client = ClaudeClient(baseUrl: _base);
    addTearDown(client.close);

    final answer = await client.createMessage(
      body: _body(ClaudeExtractor.toolName),
    );

    expect(answer['type'], 'message', reason: 'at $_base');
    final content = answer['content'] as List;
    final toolUse = content.firstWhere(
      (block) => (block as Map)['type'] == 'tool_use',
      orElse: () => throw StateError('no tool_use block in: $answer'),
    ) as Map;
    expect(toolUse['name'], ClaudeExtractor.toolName);
    expect(toolUse['input'], isA<Map>());

    stdout.writeln('extraction answered by $_base: ${toolUse['input']}');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('the planning operation is served too', () async {
    final client = ClaudeClient(baseUrl: _base);
    addTearDown(client.close);

    final answer = await client.createMessage(
      body: _body(ClaudeItineraryGenerator.toolName),
    );

    final content = answer['content'] as List;
    final toolUse = content.firstWhere(
      (block) => (block as Map)['type'] == 'tool_use',
      orElse: () => throw StateError('no tool_use block in: $answer'),
    ) as Map;
    expect(toolUse['name'], ClaudeItineraryGenerator.toolName);

    stdout.writeln('planning answered by $_base');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('an address written with the /v1 already on it works the same', () async {
    // NOOK_AI_BACKEND is typed in by hand, so both spellings turn up. Neither
    // may 404, and neither may produce `/v1/v1/messages`.
    final client = ClaudeClient(baseUrl: '$_base/v1');
    addTearDown(client.close);

    final answer = await client.createMessage(
      body: _body(ClaudeExtractor.toolName),
    );

    expect(answer['type'], 'message');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('the route that used to be asked for is still a 404', () async {
    // Proof that the fix is the client asking correctly, not the service
    // quietly answering both paths.
    final client = HttpClient();
    addTearDown(client.close);

    final request = await client.postUrl(Uri.parse('$_base/messages'));
    request.headers.contentType = ContentType.json;
    request.write('{}');
    final result = await request.close();
    final text = await result.transform(const SystemEncoding().decoder).join();

    expect(result.statusCode, 404);
    expect(
      text,
      contains('/v1/messages'),
      reason: 'the 404 has to name the path that does exist',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('the service reads a post on each of the four platforms', () async {
    // The metadata route. This is the one that did not exist: the app could
    // not read an Instagram or Facebook post at all, because a browser asking
    // those hosts for a page is a cross-origin request and is refused.
    final client = IOClient();
    addTearDown(client.close);

    const posts = {
      'tiktok': 'https://www.tiktok.com/@mika.eats/video/7311223344556677889',
      'instagram': 'https://www.instagram.com/reel/CxYzAbCdEfG/',
      'facebook': 'https://www.facebook.com/reel/1234567890',
      'youtube': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    };

    for (final entry in posts.entries) {
      final source = await SourceMetadataFetcher.fetch(
        entry.value,
        client: client,
        backendUrl: _base,
      );

      expect(
        source.fetched,
        isTrue,
        reason: '${entry.key} could not be read from $_base',
      );
      // A caption, title or not. The absence of a title is not a failure.
      expect(
        source.caption,
        isNotNull,
        reason: '${entry.key} returned no caption',
      );
      stdout.writeln(
        '${entry.key.padRight(10)} '
        'title=${source.title ?? '(none)'} | '
        'creator=${source.creator ?? source.creatorHandle ?? '(none)'} | '
        'avatar=${source.creatorAvatarUrl == null ? 'none' : 'yes'} | '
        'caption=${source.caption!.length} chars',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('a caption-only post runs the whole chain, caption intact', () async {
    // The reported symptom, end to end: a TikTok with no title whose caption
    // names a restaurant in Baguio. Nothing is mocked here.
    //
    // What is asserted is what this can honestly assert. Against
    // `serve_stub_model.mjs` the model's answer is canned, so the destination
    // it reports is the stub's and proves nothing about reading a caption —
    // only a run against the real deployment does that, and the line printed
    // below is what to read. What IS proved either way, and is the fix, is
    // that the caption survives the round trip whole and does not end up in
    // the title field.
    final client = IOClient();
    addTearDown(client.close);

    final result = await ClaudeExtractor(
      backendUrl: _base,
      httpClient: client,
    ).extract('https://www.tiktok.com/@mika.eats/video/7311223344556677889');

    expect(result.caption, isNotNull, reason: 'the caption is the post');
    expect(
      result.caption,
      contains('Baguio'),
      reason: 'the place named in the caption has to reach the far end',
    );
    expect(result.title, isNotEmpty);
    expect(
      result.title,
      isNot(result.caption),
      reason: 'a title, not the caption pasted into the title field',
    );
    stdout.writeln(
      'extracted: "${result.title}" / ${result.destination ?? '(nowhere)'} / '
      'place=${result.placeName ?? '-'} budget=${result.budgetNote ?? '-'}',
    );
    stdout.writeln('caption kept: ${result.caption}');
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('the whole extraction runs, answer parsed into a result', () async {
    // The transport tests above stop at the JSON. This one hands the answer to
    // ClaudeExtractor and reads the ExtractionResult out the far end, so the
    // tool name, the schema and the parsing are all exercised against a
    // service that really answered — which is where the second half of the bug
    // lived: with the path fixed, `record_post_details` would still have been
    // refused as an operation this service does not offer.
    //
    // Only the platform lookup is stubbed. Reading a post's own metadata is
    // not what this file is verifying, and it needs the platform's host.
    final real = IOClient();
    addTearDown(real.close);

    final client = MockClient((request) async {
      if (!request.url.toString().startsWith(_base)) {
        return http.Response(
          jsonEncode({
            'title': '5 Hidden Cafes in Kyoto',
            'author_name': 'Mia',
            'author_url': 'https://www.youtube.com/@wanderwithmia',
            'type': 'video',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      // Everything aimed at the service goes over the wire, unaltered.
      final forwarded = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await real.send(forwarded));
    });

    final result = await ClaudeExtractor(
      backendUrl: _base,
      httpClient: client,
    ).extract('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

    expect(result, isA<ExtractionResult>());
    expect(result.title, isNotEmpty);
    stdout.writeln(
      'parsed from $_base: "${result.title}" / ${result.city}, ${result.country}',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));
}
