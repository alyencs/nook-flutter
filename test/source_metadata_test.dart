import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/ai/platform_from_url.dart';
import 'package:nook/ai/source_metadata.dart';
import 'package:nook/ai/thumbnail_from_url.dart';

/// Reading the post before asking the model about it.
///
/// This is the step that did not exist. Extraction used to hand Gemini a bare
/// URL, so for the Osaka video it had `Sf9ihvL0Usk` to work from and answered
/// "Japan". These tests are about what the app now knows before the model is
/// asked anything.

/// The real oEmbed shape, with the user's video.
const _osakaUrl = 'https://www.youtube.com/watch?v=Sf9ihvL0Usk';
const _osakaTitle = 'Rainy Day in Osaka City 🌧️ hidden gem cafe in '
    'Nakazakicho 🌿 walk around Osaka station';

String get _youTubeOEmbed => jsonEncode({
      'title': _osakaTitle,
      'author_name': 'Sweet Rain',
      'author_url': 'https://www.youtube.com/@sweetrain',
      'type': 'video',
      'thumbnail_url': 'https://i.ytimg.com/vi/Sf9ihvL0Usk/hqdefault.jpg',
      'provider_name': 'YouTube',
      'html': '<iframe src="..."></iframe>',
    });

String get _tikTokOEmbed => jsonEncode({
      'type': 'video',
      // On TikTok the caption is the title.
      'title': 'the best matcha in Nakameguro ☕️ #tokyocafe',
      'author_name': 'Mia',
      'author_unique_id': 'wanderwithmia',
      'author_url': 'https://www.tiktok.com/@wanderwithmia',
      'thumbnail_url': 'https://p16.tiktokcdn.com/abc.jpeg',
      'provider_name': 'TikTok',
    });

http.Client _serving(String body, {int status = 200}) =>
    MockClient((_) async => http.Response(
          body,
          status,
          headers: {'content-type': 'application/json'},
        ));

void main() {
  group('YouTube', () {
    test('reads the real title and channel, not the video id', () async {
      final source = await SourceMetadataFetcher.fetch(
        _osakaUrl,
        client: _serving(_youTubeOEmbed),
      );

      expect(source.title, _osakaTitle);
      expect(source.creator, 'Sweet Rain');
      expect(source.creatorHandle, '@sweetrain');
      expect(source.sourceId, 'Sf9ihvL0Usk');
      expect(source.mediaType, PostMediaType.video);
      expect(source.fetched, isTrue);
    });

    test('the prompt block carries the title the model needs', () async {
      final source = await SourceMetadataFetcher.fetch(
        _osakaUrl,
        client: _serving(_youTubeOEmbed),
      );
      final block = source.toPromptBlock();

      // Everything the model needs to get past "Japan".
      expect(block, contains('Nakazakicho'));
      expect(block, contains('Osaka'));
      expect(block, contains('cafe'));
      expect(block, contains('Sweet Rain'));
      expect(block, isNot(contains('no post text could be retrieved')));
    });

    test('a video id is never mistaken for a title or a creator', () async {
      final source = SourceMetadata.fromUrlOnly(_osakaUrl);

      expect(source.sourceId, 'Sf9ihvL0Usk');
      expect(source.title, isNull);
      expect(source.creator, isNull);
      // And the model is told it is working blind.
      expect(source.toPromptBlock(), contains('no post text could be'));
    });

    for (final url in [
      'https://youtu.be/Sf9ihvL0Usk',
      'https://www.youtube.com/watch?v=Sf9ihvL0Usk&t=90s',
      'https://www.youtube.com/shorts/Sf9ihvL0Usk',
      'https://www.youtube.com/embed/Sf9ihvL0Usk',
    ]) {
      test('the id is found in ${Uri.parse(url).path}', () {
        expect(SourceIds.of(url, NookPlatform.youtube), 'Sf9ihvL0Usk');
      });
    }
  });

  group('TikTok', () {
    test('the caption is the title, and the handle is the creator', () async {
      final source = await SourceMetadataFetcher.fetch(
        'https://www.tiktok.com/@wanderwithmia/video/7300000000000000000',
        client: _serving(_tikTokOEmbed),
      );

      expect(source.title, contains('Nakameguro'));
      expect(source.creator, 'Mia');
      expect(source.creatorHandle, 'wanderwithmia');
      expect(source.mediaType, PostMediaType.video);
    });
  });

  group('platforms that publish nothing', () {
    test('Instagram falls back to the URL, and says so', () async {
      final source = await SourceMetadataFetcher.fetch(
        'https://www.instagram.com/p/C8xK2pAbCdE/',
      );

      expect(source.fetched, isFalse,
          reason: 'Meta retired public oEmbed; there is nothing to read');
      expect(source.sourceId, 'C8xK2pAbCdE');
      // A photo post, not a video.
      expect(source.mediaType, PostMediaType.image);
      expect(source.toPromptBlock(), contains('Do not guess'));
    });

    test('an Instagram reel is a video, a /p/ post is not', () {
      expect(
        SourceIds.mediaTypeFrom(
            'https://www.instagram.com/reel/C8xK2pAbCdE/', NookPlatform.instagram),
        PostMediaType.video,
      );
      expect(
        SourceIds.mediaTypeFrom(
            'https://www.instagram.com/p/C8xK2pAbCdE/', NookPlatform.instagram),
        PostMediaType.image,
      );
    });

    test('a Facebook post is not assumed to be a video', () {
      expect(
        SourceIds.mediaTypeFrom(
            'https://www.facebook.com/somepage/posts/12345',
            NookPlatform.facebook),
        PostMediaType.unknown,
      );
    });

    test('a username in the path becomes the handle', () {
      expect(
        SourceIds.handleFrom(
            'https://www.instagram.com/islandhopper.ph/p/C8xK2pAbCdE/',
            NookPlatform.instagram),
        '@islandhopper.ph',
      );
      // ...but a reserved path segment is not a username.
      expect(
        SourceIds.handleFrom(
            'https://www.instagram.com/p/C8xK2pAbCdE/', NookPlatform.instagram),
        isNull,
      );
    });
  });

  group('a lookup that fails does not fail the extraction', () {
    test('a 404 leaves the URL-only metadata', () async {
      final source = await SourceMetadataFetcher.fetch(
        _osakaUrl,
        client: _serving('nope', status: 404),
      );

      expect(source.fetched, isFalse);
      expect(source.sourceId, 'Sf9ihvL0Usk');
    });

    test('a thrown request leaves the URL-only metadata', () async {
      final source = await SourceMetadataFetcher.fetch(
        _osakaUrl,
        client: MockClient((_) async => throw const _Down()),
      );

      expect(source.fetched, isFalse);
      expect(source.mediaType, PostMediaType.video);
    });
  });

  group('thumbnails are 16:9, not letterboxed', () {
    test('a YouTube link gives the 16:9 file, never hqdefault', () {
      final url = PostThumbnails.fromUrl(_osakaUrl);

      expect(url, contains('mqdefault.jpg'));
      expect(url, isNot(contains('hqdefault')),
          reason: 'hqdefault is 480x360 with black bars baked into the pixels');
    });

    test("oEmbed's letterboxed thumbnail is rewritten to the 16:9 one",
        () async {
      final source = await SourceMetadataFetcher.fetch(
        _osakaUrl,
        client: _serving(_youTubeOEmbed),
      );
      // oEmbed hands back hqdefault.
      expect(source.thumbnailUrl, contains('hqdefault'));

      final resolved = await PostThumbnails.resolve(_osakaUrl, source: source);
      expect(resolved, contains('mqdefault.jpg'));
      expect(resolved, contains('Sf9ihvL0Usk'));
    });

    test("a platform's own thumbnail is preferred when it is not YouTube's",
        () async {
      final source = await SourceMetadataFetcher.fetch(
        'https://www.tiktok.com/@wanderwithmia/video/7300000000000000000',
        client: _serving(_tikTokOEmbed),
      );

      final resolved = await PostThumbnails.resolve(
        'https://www.tiktok.com/@wanderwithmia/video/7300000000000000000',
        source: source,
      );
      expect(resolved, 'https://p16.tiktokcdn.com/abc.jpeg');
    });
  });
}

class _Down implements Exception {
  const _Down();
}
