import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/platform_from_url.dart';
import 'package:nook/ai/source_metadata.dart';

/// All four platforms, not just the one the example happened to use.
void main() {
  const igUrl = 'https://www.instagram.com/p/Cx1y2z3AbCd/';
  const fbUrl = 'https://www.facebook.com/visitkyoto/posts/1234567890';
  const ytUrl = 'https://www.youtube.com/watch?v=sf9ihvL0Usk';
  const ttUrl = 'https://www.tiktok.com/@wanderwithmia/video/7311234567890';

  group('routing', () {
    test('YouTube and TikTok need no key at all', () {
      for (final (url, platform) in [
        (ytUrl, NookPlatform.youtube),
        (ttUrl, NookPlatform.tiktok),
      ]) {
        final endpoint = SourceMetadataFetcher.endpointFor(url, platform);
        expect(endpoint, isNotNull, reason: '$platform should be keyless');
        expect(endpoint, contains('oembed'));
        expect(endpoint, isNot(contains('access_token')));
      }
    });

    test('Instagram and Facebook go to the Graph API once a token exists', () {
      final ig = SourceMetadataFetcher.endpointFor(
        igUrl,
        NookPlatform.instagram,
        facebookToken: '123|abc',
      );
      expect(ig, contains('graph.facebook.com'));
      expect(ig, contains('instagram_oembed'));
      expect(ig, contains('access_token=123%7Cabc'));

      final fb = SourceMetadataFetcher.endpointFor(
        fbUrl,
        NookPlatform.facebook,
        facebookToken: '123|abc',
      );
      expect(fb, contains('oembed_post'));
      expect(fb, contains('access_token=123%7Cabc'));
    });

    test(
      'without a token those two have no endpoint, rather than a broken one',
      () {
        for (final token in [null, '', '   ']) {
          expect(
            SourceMetadataFetcher.endpointFor(
              igUrl,
              NookPlatform.instagram,
              facebookToken: token,
            ),
            isNull,
          );
          expect(
            SourceMetadataFetcher.endpointFor(
              fbUrl,
              NookPlatform.facebook,
              facebookToken: token,
            ),
            isNull,
          );
        }
      },
    );

    test('canReadPostText reports the real state of each platform', () {
      expect(
        SourceMetadataFetcher.canReadPostText(NookPlatform.youtube),
        isTrue,
      );
      expect(
        SourceMetadataFetcher.canReadPostText(NookPlatform.tiktok),
        isTrue,
      );
      expect(
        SourceMetadataFetcher.canReadPostText(NookPlatform.instagram),
        isFalse,
        reason: 'no service and no token: a browser cannot fetch the page',
      );
      expect(
        SourceMetadataFetcher.canReadPostText(
          NookPlatform.instagram,
          facebookToken: '123|abc',
        ),
        isTrue,
      );
    });

    test('with a service configured, all four can be read', () {
      // The asymmetry was never about what the platforms publish. It was
      // about who was asking: a static site has an origin and a server does
      // not, so the same public page a browser is refused is an ordinary GET
      // from Nook's own service.
      for (final platform in [
        NookPlatform.youtube,
        NookPlatform.tiktok,
        NookPlatform.instagram,
        NookPlatform.facebook,
      ]) {
        expect(
          SourceMetadataFetcher.canReadPostText(
            platform,
            backendUrl: 'https://nook-ai.example.workers.dev',
          ),
          isTrue,
          reason: platform,
        );
      }
    });
  });

  group('ids and handles', () {
    test('each platform yields its own id shape', () {
      expect(SourceIds.of(ytUrl, NookPlatform.youtube), 'sf9ihvL0Usk');
      expect(SourceIds.of(ttUrl, NookPlatform.tiktok), '7311234567890');
      expect(SourceIds.of(igUrl, NookPlatform.instagram), 'Cx1y2z3AbCd');
      expect(SourceIds.of(fbUrl, NookPlatform.facebook), '1234567890');
    });

    test('Facebook covers its other post shapes too', () {
      expect(
        SourceIds.of(
          'https://www.facebook.com/reel/987654321',
          NookPlatform.facebook,
        ),
        '987654321',
      );
      expect(
        SourceIds.of(
          'https://www.facebook.com/watch/?v=55512345',
          NookPlatform.facebook,
        ),
        '55512345',
      );
      expect(
        SourceIds.of('https://fb.watch/aBcDeFg/', NookPlatform.facebook),
        'aBcDeFg',
      );
      expect(
        SourceIds.of(
          'https://www.facebook.com/visitkyoto/videos/778899',
          NookPlatform.facebook,
        ),
        '778899',
      );
    });

    test('a handle is read from the path where the platform puts one', () {
      expect(
        SourceIds.handleFrom(ttUrl, NookPlatform.tiktok),
        '@wanderwithmia',
      );
      expect(SourceIds.handleFrom(fbUrl, NookPlatform.facebook), '@visitkyoto');
    });

    test(
      'media type follows the URL shape, and is never assumed to be video',
      () {
        expect(
          SourceIds.mediaTypeFrom(ytUrl, NookPlatform.youtube),
          PostMediaType.video,
        );
        expect(
          SourceIds.mediaTypeFrom(ttUrl, NookPlatform.tiktok),
          PostMediaType.video,
        );
        expect(
          SourceIds.mediaTypeFrom(igUrl, NookPlatform.instagram),
          PostMediaType.image,
          reason: 'an Instagram /p/ is a photo post, not a video',
        );
        expect(
          SourceIds.mediaTypeFrom(
            'https://www.instagram.com/reel/abc/',
            NookPlatform.instagram,
          ),
          PostMediaType.video,
        );
      },
    );
  });

  group('what the model is told', () {
    SourceMetadata source(
      String platform, {
      bool fetched = false,
      String? desc,
    }) => SourceMetadata(
      platform: platform,
      url: 'https://example.com/x',
      title: fetched ? 'A title' : null,
      description: desc,
      fetched: fetched,
    );

    test('an unreadable Meta post says why, and forbids guessing', () {
      for (final platform in [NookPlatform.instagram, NookPlatform.facebook]) {
        final block = source(platform).toPromptBlock();
        // The cause is carried from whatever actually failed rather than
        // asserted here. It used to be fixed text naming 2020 and the missing
        // Meta token, which stopped being true once the service began reading
        // these posts: the live reasons are now "private", "deleted" or
        // "nothing readable", and the note repeats the one that applies.
        expect(block, contains('could not be read'));
        expect(block.toLowerCase(), contains('do not guess'));
        expect(block.toLowerCase(), contains('null'));
      }
    });

    test('the reason a post could not be read is passed through', () {
      final block = SourceMetadata(
        platform: NookPlatform.instagram,
        url: 'https://example.com/x',
        fetched: false,
        unreadableReason: 'This post is not public — the platform served a '
            'sign-in page instead of the post.',
      ).toPromptBlock();

      expect(block, contains('not public'));
      expect(block, contains('sign-in page'));
      expect(block.toLowerCase(), contains('do not guess'));
    });

    test(
      'each readable platform gets guidance about where its detail lives',
      () {
        expect(
          source(
            NookPlatform.youtube,
            fetched: true,
            desc: 'x',
          ).toPromptBlock(),
          contains('description'),
        );
        expect(
          source(NookPlatform.tiktok, fetched: true, desc: 'x').toPromptBlock(),
          contains('hashtag'),
        );
        expect(
          source(
            NookPlatform.instagram,
            fetched: true,
            desc: 'x',
          ).toPromptBlock(),
          contains('carousel'),
        );
        expect(
          source(
            NookPlatform.facebook,
            fetched: true,
            desc: 'x',
          ).toPromptBlock(),
          contains('post body'),
        );
      },
    );

    test('a caption-only post is told the caption is the post', () {
      // A TikTok with text but no description. This used to be described to
      // the model as "only the title or caption was available … extract what
      // it supports and leave the rest null", which reads as an apology for a
      // thin source and is the opposite of what is wanted: on this platform a
      // caption with no title is the whole post and should be read closely.
      final block = source(NookPlatform.tiktok, fetched: true).toPromptBlock();

      expect(block, contains('CAPTION:'));
      expect(block, contains('NO TITLE'));
      expect(block, contains('The CAPTION is the post'));
    });

    test('a post with nothing readable at all still says so', () {
      final block = SourceMetadata(
        platform: NookPlatform.tiktok,
        url: 'https://example.com/x',
        fetched: true,
      ).toPromptBlock();

      expect(block, contains('no title, no caption'));
      expect(block, contains('leave the rest null'));
    });

    test('every platform is named in the block it produces', () {
      for (final platform in NookPlatform.supported) {
        expect(
          source(platform, fetched: true, desc: 'x').toPromptBlock(),
          contains('PLATFORM: ${NookPlatform.label(platform)}'),
        );
      }
    });
  });
}
