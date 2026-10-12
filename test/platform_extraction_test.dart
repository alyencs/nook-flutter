import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/ai/ai_extractor.dart';
import 'package:nook/ai/claude_extractor.dart';
import 'package:nook/ai/post_place.dart';
import 'package:nook/ai/source_metadata.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/add/post_draft.dart';
import 'package:nook/widgets/creator_avatar.dart';

/// Extraction across the four platforms, and the ways it used to lose things.
///
/// The symptom was that TikTok and Instagram "sometimes" found a creator while
/// Facebook never did, and none of the three ever found a destination. All of
/// that had one cause and two consequences:
///
/// * Instagram and Facebook had no reachable metadata source at all. A browser
///   asking instagram.com for a page is a cross-origin request, so the app's
///   only route was a Meta app token, and the deploy workflow passes no
///   credentials — a published build never had one. Those posts reached the
///   model as a bare URL.
/// * The "sometimes" was never a lookup. `@wanderwithmia` falls out of
///   `tiktok.com/@wanderwithmia/video/123` with no network at all, and
///   Instagram post URLs carry a username the same way. Facebook's do not —
///   `/reel/<id>`, `/watch/?v=<id>` and `fb.watch/<code>` have no username in
///   them — which is exactly why Facebook looked worse than the other two.
///
/// Every fixture here is invented. No real account or caption appears.
void main() {
  const backend = 'https://nook-ai.example.workers.dev';

  /// A model reply carrying one tool call, so the extractor gets that far.
  String modelReply(Map<String, Object?> input) => jsonEncode({
    'id': 'msg_test',
    'type': 'message',
    'role': 'assistant',
    'stop_reason': 'tool_use',
    'content': [
      {
        'type': 'tool_use',
        'id': 'toolu_1',
        'name': ClaudeExtractor.toolName,
        'input': {'title': 'A post', 'category': 'Other', ...input},
      },
    ],
  });

  /// Answers the service's metadata route with [metadata] and the model call
  /// with [toolInput], and records the prompt the model was given.
  ({ClaudeExtractor extractor, List<String> prompts}) wired({
    required Map<String, Object?> metadata,
    Map<String, Object?> toolInput = const {},
  }) {
    final prompts = <String>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/v1/metadata')) {
        return http.Response(
          jsonEncode(metadata),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/v1/messages')) {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final messages = body['messages'] as List;
        prompts.add(
          '${body['system']}\n${(messages.first as Map)['content']}',
        );
        return http.Response(
          modelReply(toolInput),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      // Any direct platform call: this build reads through the service.
      return http.Response('{}', 404);
    });

    return (
      extractor: ClaudeExtractor(backendUrl: backend, httpClient: client),
      prompts: prompts,
    );
  }

  group('a caption with no title is a complete post', () {
    // The example from the report: a TikTok naming a restaurant in Baguio,
    // with no title at all.
    const tiktokCaption =
        '₱150 lang ang unlimited wings sa Good Taste Baguio! Open 24 hours, '
        '2nd floor pa #baguio #baguiofood #fyp';

    const tiktok = {
      'platform': 'tiktok',
      'url': 'https://www.tiktok.com/@mika.eats/video/7311223344556677889',
      'title': null,
      'caption': tiktokCaption,
      'hashtags': ['baguio', 'baguiofood', 'fyp'],
      'creator': 'Mika Eats',
      'creatorHandle': '@mika.eats',
      'creatorUrl': 'https://www.tiktok.com/@mika.eats',
      'creatorAvatarUrl': 'https://cdn.test/avatar/mika.jpg',
      'thumbnailUrl': 'https://cdn.test/thumb/7311223344556677889.jpg',
      'mediaType': 'video',
      'fetched': true,
      'reason': null,
    };

    test('the caption reaches the model, labelled as the caption', () async {
      final w = wired(metadata: tiktok);
      await w.extractor.extract(tiktok['url']! as String);

      expect(w.prompts, hasLength(1));
      final prompt = w.prompts.single;

      expect(prompt, contains('CAPTION:'));
      expect(prompt, contains('Good Taste Baguio'));
      expect(prompt, contains('₱150'));
      // And the absent title is stated as normal rather than left to look like
      // an empty post. Asserted on the per-post NOTE, not on the standing
      // instructions, which say it for every post whether or not it applies.
      expect(prompt, contains('TITLE: (none'));
      expect(prompt, contains('This post has NO TITLE'));
      expect(prompt, contains('The CAPTION is the post'));
      expect(prompt, contains('HASHTAGS: #baguio #baguiofood #fyp'));
    });

    test('a hashtag is marked as weak evidence, not as a fact', () async {
      final w = wired(metadata: tiktok);
      await w.extractor.extract(tiktok['url']! as String);

      expect(w.prompts.single, contains('weak evidence'));
      expect(w.prompts.single, contains('#fyp'));
    });

    test('the caption is stored as the caption, not as the title', () async {
      final w = wired(
        metadata: tiktok,
        toolInput: {
          'title': 'Unlimited wings at Good Taste in Baguio',
          'place_name': 'Good Taste',
          'city': 'Baguio City',
          'country': 'Philippines',
          'budget_note': '₱150 for unlimited wings',
          'latitude': 16.4145,
          'longitude': 120.5960,
        },
      );

      final result = await w.extractor.extract(tiktok['url']! as String);

      // The whole caption, in the caption field.
      expect(result.caption, tiktokCaption);
      // A short title, not the caption pasted into the title field. This is
      // what used to happen: `source.title` won unconditionally, so a
      // paragraph became the post's name and the caption column stayed empty.
      expect(result.title, 'Unlimited wings at Good Taste in Baguio');
      expect(result.title.length, lessThan(tiktokCaption.length));

      // The details the caption supports.
      expect(result.placeName, 'Good Taste');
      expect(result.city, 'Baguio City');
      expect(result.country, 'Philippines');
      expect(result.budgetNote, '₱150 for unlimited wings');
      expect(result.destination, 'Good Taste, Baguio City');
      expect(result.hasCoordinates, isTrue);
    });

    test('a title that is really the caption is not used as a title', () {
      // What TikTok's oEmbed returns: the caption, in the `title` field.
      final source = SourceMetadata(
        platform: 'tiktok',
        url: 'https://www.tiktok.com/@a/video/1',
        title: tiktokCaption,
        fetched: true,
      );

      expect(source.caption, tiktokCaption);
      expect(source.hasCaption, isTrue);
      // It still reaches the model as the caption, under "no title".
      expect(source.toPromptBlock(), contains('CAPTION:'));
      expect(source.toPromptBlock(), contains('Good Taste Baguio'));
    });
  });

  group('Instagram Reels', () {
    const reel = {
      'platform': 'instagram',
      'url': 'https://www.instagram.com/reel/CxYzAbCdEfG/',
      'title': null,
      'caption':
          'Three days in Kyoto and the best meal was a ¥900 set lunch at '
          'Kissa Master in Gion. Go before 11am. #kyoto #japantravel',
      'hashtags': ['kyoto', 'japantravel'],
      'creator': null,
      'creatorHandle': '@nina.reyes',
      'creatorUrl': 'https://www.instagram.com/nina.reyes/',
      'creatorAvatarUrl': 'https://cdn.test/avatar/nina.jpg',
      'thumbnailUrl': 'https://cdn.test/reel.jpg',
      'mediaType': 'video',
      'fetched': true,
      'reason': null,
    };

    test('creator and caption survive with no title present', () async {
      final w = wired(
        metadata: reel,
        toolInput: {
          'title': 'A set lunch in Gion, Kyoto',
          'place_name': 'Kissa Master',
          'neighbourhood': 'Gion',
          'city': 'Kyoto',
          'country': 'Japan',
          'budget_note': '¥900 set lunch',
          'best_time': 'Before 11am',
        },
      );

      final result = await w.extractor.extract(reel['url']! as String);

      // A Reel URL carries no username, so this handle can only have come
      // from the lookup — which is the thing that did not exist before.
      expect(result.creatorHandle, '@nina.reyes');
      expect(result.creatorUrl, 'https://www.instagram.com/nina.reyes/');
      expect(result.creatorAvatarUrl, 'https://cdn.test/avatar/nina.jpg');
      expect(result.caption, contains('Kissa Master'));
      expect(result.placeName, 'Kissa Master');
      expect(result.neighbourhood, 'Gion');
      expect(result.city, 'Kyoto');
      expect(result.budgetNote, '¥900 set lunch');
      expect(result.bestTime, 'Before 11am');
    });

    test('the avatar is kept distinct from the post thumbnail', () async {
      final w = wired(metadata: reel);
      final result = await w.extractor.extract(reel['url']! as String);

      expect(result.creatorAvatarUrl, isNot(result.thumbnailUrl));
      expect(result.creatorAvatarUrl, 'https://cdn.test/avatar/nina.jpg');
    });
  });

  group('Facebook', () {
    test('a reel URL yields a creator, which it never used to', () async {
      const reel = {
        'platform': 'facebook',
        'url': 'https://www.facebook.com/reel/1234567890',
        'title': null,
        'caption':
            'Sagada in two days: ₱800 for the cave tour, ₱2,500 a night at a '
            'homestay. The sunrise at Kiltepan is worth the 4am start.',
        'hashtags': <String>[],
        'creator': 'Alex Cruz',
        'creatorHandle': '@alex.cruz.travels',
        'creatorUrl': 'https://www.facebook.com/alex.cruz.travels',
        'creatorAvatarUrl': 'https://cdn.test/avatar/alex.jpg',
        'thumbnailUrl': 'https://cdn.test/fb-reel.jpg',
        'mediaType': 'video',
        'fetched': true,
        'reason': null,
      };

      final w = wired(
        metadata: reel,
        toolInput: {
          'title': 'Two days in Sagada',
          'city': 'Sagada',
          'country': 'Philippines',
          'budget_note': '₱800 cave tour, ₱2,500 a night',
          'highlights': ['Sunrise at Kiltepan', 'Cave tour'],
        },
      );

      final result = await w.extractor.extract(reel['url']! as String);

      // The URL alone gives none of this: `/reel/<id>` has no username in it.
      expect(SourceMetadata.fromUrlOnly(reel['url']! as String).creatorHandle, isNull);
      expect(result.creator, 'Alex Cruz');
      expect(result.creatorHandle, '@alex.cruz.travels');
      expect(result.creatorAvatarUrl, 'https://cdn.test/avatar/alex.jpg');
      expect(result.city, 'Sagada');
      expect(result.budgetNote, '₱800 cave tour, ₱2,500 a night');
      expect(result.highlights, hasLength(2));
    });

    test('a short link no longer invents a creator from its share code', () {
      // `fb.watch/aBcDeFgHiJ` read as `@aBcDeFgHiJ`: a fabricated creator,
      // worse than a blank one because it looks like a fact.
      for (final url in [
        'https://fb.watch/aBcDeFgHiJ/',
        'https://fb.watch/aBcDeFgHiJ',
        'https://vt.tiktok.com/ZSAbCdEf/',
        'https://vm.tiktok.com/ZSAbCdEf/',
      ]) {
        expect(
          SourceMetadata.fromUrlOnly(url).creatorHandle,
          isNull,
          reason: 'a share code is not an account: $url',
        );
      }
    });

    test('a numeric or pfbid path segment is not read as a username', () {
      for (final url in [
        'https://www.facebook.com/123456789/posts/987654321',
        'https://www.facebook.com/pfbid0abc/posts/1',
        'https://www.facebook.com/watch/?v=1234567890',
        'https://www.facebook.com/reel/1234567890',
      ]) {
        expect(SourceMetadata.fromUrlOnly(url).creatorHandle, isNull, reason: url);
      }
    });

    test('a real page name in the path still is read as one', () {
      expect(
        SourceMetadata.fromUrlOnly(
          'https://www.facebook.com/alex.cruz.travels/posts/pfbid0123',
        ).creatorHandle,
        '@alex.cruz.travels',
      );
      expect(
        SourceMetadata.fromUrlOnly(
          'https://www.instagram.com/nina.reyes/p/CxYzAbCdEfG/',
        ).creatorHandle,
        '@nina.reyes',
      );
    });
  });

  group('YouTube keeps working', () {
    const video = {
      'platform': 'youtube',
      'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      'title': '5 Hidden Cafes in Kyoto',
      'caption': 'Five small coffee bars in Kyoto, within a short walk.',
      'hashtags': <String>[],
      'creator': 'Wander With Mia',
      'creatorHandle': '@wanderwithmia',
      'creatorUrl': 'https://www.youtube.com/@wanderwithmia',
      'creatorAvatarUrl': null,
      'thumbnailUrl': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      'mediaType': 'video',
      'fetched': true,
      'reason': null,
    };

    test('a real title stays the title, with the description beneath', () async {
      final w = wired(
        metadata: video,
        toolInput: {'title': 'Cafes in Kyoto', 'city': 'Kyoto'},
      );

      final result = await w.extractor.extract(video['url']! as String);

      // YouTube has real titles, so the platform's wins over the model's.
      expect(result.title, '5 Hidden Cafes in Kyoto');
      expect(result.caption, 'Five small coffee bars in Kyoto, within a short walk.');
      expect(result.creator, 'Wander With Mia');
    });

    test('the prompt carries both the title and the description', () async {
      final w = wired(metadata: video);
      await w.extractor.extract(video['url']! as String);

      final prompt = w.prompts.single;
      expect(prompt, contains('TITLE:\n5 Hidden Cafes in Kyoto'));
      expect(prompt, contains('CAPTION:'));
      // The per-post note does not claim this post lacks a title.
      expect(prompt, isNot(contains('TITLE: (none')));
      expect(prompt, isNot(contains('This post has NO TITLE')));
    });
  });

  group('what cannot be read is said, not guessed', () {
    test('a private post carries its reason into the prompt', () async {
      const private = {
        'platform': 'instagram',
        'url': 'https://www.instagram.com/p/PrivateAbc/',
        'title': null,
        'caption': null,
        'hashtags': <String>[],
        'creator': null,
        'creatorHandle': null,
        'creatorUrl': null,
        'creatorAvatarUrl': null,
        'thumbnailUrl': null,
        'mediaType': 'unknown',
        'fetched': false,
        'reason': 'This post is not public — the platform served a sign-in '
            'page instead of the post.',
      };

      final w = wired(metadata: private);
      await w.extractor.extract(private['url']! as String);

      final prompt = w.prompts.single;
      expect(prompt, contains('could not be read'));
      expect(prompt, contains('not public'));
      expect(prompt, contains('Do not guess'));
    });

    test('the service being unreachable degrades instead of failing', () async {
      // The metadata route 500s. Extraction still runs on the URL alone,
      // which is the old behaviour and remains the floor rather than the
      // ceiling.
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/v1/metadata')) {
          return http.Response('upstream is down', 500);
        }
        if (request.url.path.endsWith('/v1/messages')) {
          return http.Response(
            modelReply({'title': 'A saved link'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final result = await ClaudeExtractor(
        backendUrl: backend,
        httpClient: client,
      ).extract('https://www.tiktok.com/@mika.eats/video/1');

      expect(result.title, isNotEmpty);
      // The handle the URL itself carries is not lost by the lookup failing.
      expect(result.creatorHandle, '@mika.eats');
    });
  });

  group('values from one source do not erase another', () {
    test('a lookup with no handle keeps the one the URL gave', () async {
      final w = wired(
        metadata: const {
          'platform': 'tiktok',
          'url': 'https://www.tiktok.com/@mika.eats/video/1',
          'title': null,
          'caption': 'A cafe in Kyoto',
          'creator': 'Mika Eats',
          // The service read a caption but no handle.
          'creatorHandle': null,
          'creatorUrl': null,
          'creatorAvatarUrl': null,
          'thumbnailUrl': null,
          'mediaType': 'video',
          'fetched': true,
          'reason': null,
        },
      );

      final result = await w.extractor.extract(
        'https://www.tiktok.com/@mika.eats/video/1',
      );

      expect(result.creator, 'Mika Eats');
      expect(
        result.creatorHandle,
        '@mika.eats',
        reason: 'the URL already knew this; a lookup that misses must not '
            'overwrite it with null',
      );
    });

    test('a malformed or relative avatar URL is made safe or dropped', () {
      expect(
        SourceMetadataFetcher.sanitiseImageUrl('//cdn.test/a.jpg'),
        'https://cdn.test/a.jpg',
      );
      expect(
        SourceMetadataFetcher.sanitiseImageUrl('  https://cdn.test/a.jpg  '),
        'https://cdn.test/a.jpg',
      );
      for (final bad in [
        null,
        '',
        '   ',
        'javascript:alert(1)',
        'data:image/png;base64,AAAA',
        'not a url',
        '/relative/only.jpg',
      ]) {
        expect(
          SourceMetadataFetcher.sanitiseImageUrl(bad),
          isNull,
          reason: 'would reach Image.network as "$bad"',
        );
      }
    });

    test('a model answer never overwrites a caption the platform published', () async {
      final w = wired(
        metadata: const {
          'platform': 'tiktok',
          'url': 'https://www.tiktok.com/@a/video/1',
          'title': null,
          'caption': 'The exact words of the post, ₱150, #baguio',
          'creator': null,
          'creatorHandle': null,
          'creatorUrl': null,
          'creatorAvatarUrl': null,
          'thumbnailUrl': null,
          'mediaType': 'video',
          'fetched': true,
          'reason': null,
        },
        toolInput: {'caption': 'A paraphrase the model wrote'},
      );

      final result = await w.extractor.extract('https://www.tiktok.com/@a/video/1');

      expect(result.caption, 'The exact words of the post, ₱150, #baguio');
    });
  });

  group('into the row and onto the screen', mappingTests);

  group('when the service cannot read the post', serviceFailureTests);

  group('short links', () {
    test('the resolved address is given to the model', () {
      final source = SourceMetadata(
        platform: 'tiktok',
        url: 'https://vt.tiktok.com/ZSAbCdEf/',
        canonicalUrl: 'https://www.tiktok.com/@mika.eats/video/7311223344556677889',
        title: 'A caption',
        fetched: true,
      );

      expect(source.toPromptBlock(), contains('RESOLVED_URL:'));
      expect(source.toPromptBlock(), contains('7311223344556677889'));
    });
  });
}

/// The second half of the question: a value in a backend answer is no use if
/// the frontend drops it. This walks a caption-only post the rest of the way —
/// into the draft, into the row, and onto the screen.
void mappingTests() {
  const reelUrl = 'https://www.instagram.com/reel/CxYzAbCdEfG/';

  test('every extracted field reaches the row the save screen writes', () async {
    final db = NookDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    const result = ExtractionResult(
      title: 'A set lunch in Gion, Kyoto',
      caption: 'Three days in Kyoto, a ¥900 set lunch at Kissa Master in Gion. '
          '#kyoto #japantravel',
      creator: null,
      creatorHandle: '@nina.reyes',
      creatorUrl: 'https://www.instagram.com/nina.reyes/',
      creatorAvatarUrl: 'https://cdn.test/avatar/nina.jpg',
      destination: 'Kissa Master, Gion',
      placeName: 'Kissa Master',
      address: '87-5 Hoshinocho, Higashiyama Ward',
      neighbourhood: 'Gion',
      city: 'Kyoto',
      region: 'Kansai',
      country: 'Japan',
      category: 'Food',
      summary: 'A row of small coffee bars worth an early start.',
      bestTime: 'Before 11am',
      budgetNote: '¥900 set lunch',
      latitude: 34.9971,
      longitude: 135.7788,
      thumbnailUrl: 'https://cdn.test/reel.jpg',
      sourceId: 'CxYzAbCdEfG',
      mediaType: PostMediaType.video,
      highlights: ['Go before 11am'],
    );

    final draft = PostDraft.fromLink(url: reelUrl, result: result);

    // The two the UI was losing: a caption with no title behind it, and an
    // avatar for a creator with no display name.
    expect(draft.caption, contains('Kissa Master'));
    expect(draft.creatorAvatarUrl, 'https://cdn.test/avatar/nina.jpg');
    expect(draft.creatorHandle, '@nina.reyes');
    expect(draft.creator, isNull);

    // The same field set `review_save_screen.dart` writes.
    final id = await PostsDao(db).insertPost(
      SavedPostsCompanion.insert(
        title: draft.title,
        caption: Value(draft.caption),
        creator: Value(draft.creator),
        creatorHandle: Value(draft.creatorHandle),
        creatorUrl: Value(draft.creatorUrl),
        creatorAvatarUrl: Value(draft.creatorAvatarUrl),
        platform: draft.platform,
        originalUrl: Value(draft.url),
        sourceId: Value(draft.sourceId),
        mediaType: Value(draft.mediaType.name),
        importMethod: draft.importMethod,
        aiDestination: Value(draft.destination),
        aiPlaceName: Value(draft.placeName),
        aiAddress: Value(draft.address),
        aiNeighbourhood: Value(draft.neighbourhood),
        aiCity: Value(draft.city),
        aiRegion: Value(draft.region),
        aiCountry: Value(draft.country),
        aiCategory: Value(draft.category),
        aiSummary: Value(draft.summary),
        aiBestTime: Value(draft.bestTime),
        aiBudgetNote: Value(draft.budgetNote),
        aiHighlights: Value(PostHighlights.encode(draft.highlights)),
        aiLatitude: Value(draft.latitude),
        aiLongitude: Value(draft.longitude),
        thumbnailUrl: Value(draft.thumbnailUrl),
        dateSaved: DateTime.now(),
      ),
    );

    final saved = await PostsDao(db).watchPost(id).first;
    expect(saved, isNotNull);
    expect(saved!.caption, contains('Kissa Master'));
    expect(saved.creatorHandle, '@nina.reyes');
    expect(saved.creatorUrl, 'https://www.instagram.com/nina.reyes/');
    expect(saved.creatorAvatarUrl, 'https://cdn.test/avatar/nina.jpg');
    expect(saved.aiPlaceName, 'Kissa Master');
    expect(saved.aiAddress, '87-5 Hoshinocho, Higashiyama Ward');
    expect(saved.aiNeighbourhood, 'Gion');
    expect(saved.aiCity, 'Kyoto');
    expect(saved.aiRegion, 'Kansai');
    expect(saved.aiCountry, 'Japan');
    expect(saved.aiBestTime, 'Before 11am');
    expect(saved.aiBudgetNote, '¥900 set lunch');
    expect(saved.aiLatitude, closeTo(34.9971, 0.001));
    expect(PostHighlights.decode(saved.aiHighlights), ['Go before 11am']);
  });

  testWidgets('the creator shows with a handle and no display name', (tester) async {
    // The whole row used to be gated on the display name, so on Instagram and
    // Facebook — where a handle is often all any public source gives — the
    // creator was extracted, saved, and then never drawn.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              CreatorAvatar(name: '@nina.reyes'),
              Text('@nina.reyes'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('@nina.reyes'), findsOneWidget);
    // The initial skips the `@` rather than drawing it.
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('a null avatar draws the initial instead of a broken image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CreatorAvatar(name: 'Mika Eats', avatarUrl: null)),
      ),
    );

    expect(find.text('M'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an unknown creator draws a placeholder, not an empty circle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreatorAvatar(name: null))),
    );

    expect(find.text('·'), findsOneWidget);
  });
}

/// What the app does when the service cannot read the post.
///
/// The failure these cover is the one that made the whole previous round look
/// like it had changed nothing: `_fromService` returned null on any non-200
/// and the app fell through to the URL alone, silently. A service still
/// running a build from before `/v1/metadata` existed is indistinguishable,
/// from inside the app, from Instagram and Facebook publishing nothing — same
/// blank fields, same absent creator, no clue which.
void serviceFailureTests() {
  const backend = 'https://nook-ai.example.workers.dev';
  const tiktok = 'https://www.tiktok.com/@mika.eats/video/7311223344556677889';

  /// Answers the metadata route with [status], and nothing else.
  http.Client refusing(int status, {String body = 'nope'}) =>
      MockClient((request) async {
        if (request.url.path.endsWith('/v1/metadata')) {
          return http.Response(body, status);
        }
        return http.Response('{}', 404);
      });

  test('a 404 on the metadata route names the redeploy', () async {
    final source = await SourceMetadataFetcher.fetch(
      tiktok,
      client: refusing(404),
      backendUrl: backend,
    );

    expect(source.fetched, isFalse);
    expect(source.unreadableReason, isNotNull);
    expect(
      source.unreadableReason,
      contains('/v1/metadata'),
      reason: 'the route being absent is the cause, and it is fixable',
    );
    expect(source.unreadableReason, contains('wrangler deploy'));
    // And it reaches the model, so the answer is not a confident set of nulls.
    expect(source.toPromptBlock(), contains('/v1/metadata'));
  });

  test('a 500 says the service failed, not that the post is empty', () async {
    final source = await SourceMetadataFetcher.fetch(
      tiktok,
      client: refusing(500),
      backendUrl: backend,
    );

    expect(source.fetched, isFalse);
    expect(source.unreadableReason, contains('500'));
  });

  test('an unparseable answer is reported rather than swallowed', () async {
    final source = await SourceMetadataFetcher.fetch(
      tiktok,
      client: refusing(200, body: 'not json at all'),
      backendUrl: backend,
    );

    expect(source.fetched, isFalse);
    expect(source.unreadableReason, isNotNull);
  });

  test('the URL-derived handle is still kept when the service fails', () async {
    final source = await SourceMetadataFetcher.fetch(
      tiktok,
      client: refusing(404),
      backendUrl: backend,
    );

    // Degrading is fine. Losing what the URL already told us is not.
    expect(source.creatorHandle, '@mika.eats');
    expect(source.sourceId, '7311223344556677889');
  });

  test('a reason reaches the review screen through the draft', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/v1/metadata')) {
        return http.Response('nope', 404);
      }
      if (request.url.path.endsWith('/v1/messages')) {
        return http.Response(
          jsonEncode({
            'id': 'm',
            'type': 'message',
            'role': 'assistant',
            'stop_reason': 'tool_use',
            'content': [
              {
                'type': 'tool_use',
                'id': 't',
                'name': ClaudeExtractor.toolName,
                'input': {'title': 'A saved link', 'category': 'Other'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    final result = await ClaudeExtractor(
      backendUrl: backend,
      httpClient: client,
    ).extract(tiktok);

    expect(result.sourceNote, isNotNull);
    expect(result.sourceNote, contains('/v1/metadata'));

    final draft = PostDraft.fromLink(url: tiktok, result: result);
    expect(draft.sourceNote, contains('/v1/metadata'));
  });

  test('a post that WAS read carries no notice', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/v1/metadata')) {
        return http.Response(
          jsonEncode({
            'platform': 'tiktok',
            'url': tiktok,
            'title': null,
            'caption': 'Good Taste Baguio, ₱150 unlimited wings',
            'hashtags': <String>[],
            'creator': 'Mika Eats',
            'creatorHandle': '@mika.eats',
            'creatorUrl': null,
            'creatorAvatarUrl': null,
            'thumbnailUrl': null,
            'mediaType': 'video',
            'fetched': true,
            'reason': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'id': 'm',
          'type': 'message',
          'role': 'assistant',
          'stop_reason': 'tool_use',
          'content': [
            {
              'type': 'tool_use',
              'id': 't',
              'name': ClaudeExtractor.toolName,
              'input': {'title': 'Wings in Baguio', 'category': 'Food'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await ClaudeExtractor(
      backendUrl: backend,
      httpClient: client,
    ).extract(tiktok);

    expect(result.sourceNote, isNull, reason: 'nothing to explain on a success');
    expect(result.caption, contains('Good Taste Baguio'));
  });
}
