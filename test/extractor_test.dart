import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/ai_extractor.dart';
import 'package:nook/ai/categories.dart';
import 'package:nook/ai/platform_from_url.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/ai/thumbnail_from_url.dart';

void main() {
  group('platform detection', () {
    test('recognises the four supported platforms from the host', () {
      expect(
        NookPlatform.fromUrl('https://www.tiktok.com/@x/video/1'),
        NookPlatform.tiktok,
      );
      expect(
        NookPlatform.fromUrl('https://www.instagram.com/reel/abc'),
        NookPlatform.instagram,
      );
      expect(NookPlatform.fromUrl('https://fb.watch/xyz'), NookPlatform.facebook);
      expect(NookPlatform.fromUrl('https://youtu.be/abc'), NookPlatform.youtube);
    });

    test('anything else is still savable, just labelled a link', () {
      expect(NookPlatform.fromUrl('https://example.com/post'), NookPlatform.other);
      expect(NookPlatform.label(NookPlatform.other), 'Link');
      expect(NookPlatform.label(NookPlatform.tiktok), 'TikTok');
    });
  });

  group('categories', () {
    test('the vocabulary is the union of both mockup lists', () {
      expect(NookCategories.all, hasLength(8));
      expect(NookCategories.all, contains('Travel'));   // Search chips
      expect(NookCategories.all, contains('Nightlife')); // Add chips
    });

    test('an unknown or missing category falls back to Other', () {
      expect(NookCategories.normalise(null), 'Other');
      expect(NookCategories.normalise('Restaurants'), 'Other');
      expect(NookCategories.normalise(''), 'Other');
    });

    test('matching is case-insensitive', () {
      expect(NookCategories.normalise('food'), 'Food');
      expect(NookCategories.normalise('  ACCOMMODATION '), 'Accommodation');
    });
  });

  group('thumbnails', () {
    test('derives a YouTube thumbnail from every URL shape', () {
      const id = 'dQw4w9WgXcQ';
      for (final url in [
        'https://www.youtube.com/watch?v=$id',
        'https://youtu.be/$id',
        'https://www.youtube.com/shorts/$id',
        'https://www.youtube.com/embed/$id?start=30',
      ]) {
        expect(
          PostThumbnails.fromUrl(url),
          'https://img.youtube.com/vi/$id/mqdefault.jpg',
          reason: url,
        );
      }
    });

    test('refuses to invent one from a slug that is not a video id', () {
      // The seeded demo links look like this. Guessing would produce a URL that
      // 404s, and a broken image is worse than the placeholder.
      expect(
        PostThumbnails.fromUrl(
          'https://www.youtube.com/watch?v=lisbon-3-day-itinerary-budget',
        ),
        isNull,
      );
    });

    test('has none for platforms without a public endpoint', () {
      // Instagram and Facebook both retired public oEmbed; reading a thumbnail
      // now needs a Meta app and an access token.
      expect(
        PostThumbnails.fromUrl('https://www.instagram.com/reel/abc123'),
        isNull,
      );
      expect(PostThumbnails.fromUrl('https://fb.watch/xyz'), isNull);
      expect(PostThumbnails.fromUrl('https://example.com/a-post'), isNull);
    });
  });

  group('sample extractor', () {
    const extractor = SampleExtractor();

    test('is not live, and says so on every result', () async {
      expect(extractor.isLive, isFalse);
      final result = await extractor.extract('https://www.tiktok.com/@a/video/b-c');
      expect(result.isSample, isTrue);
    });

    test('is deterministic: the same link always extracts the same way', () async {
      const url = 'https://www.tiktok.com/@someone/video/a-quiet-week-in-hanoi';
      final first = await extractor.extract(url);
      final second = await extractor.extract(url);
      expect(first.title, second.title);
      expect(first.destination, second.destination);
      expect(first.category, second.category);
    });

    test('prefers a fixture the link actually mentions', () async {
      final result = await extractor.extract(
        'https://www.tiktok.com/@wanderwithmia/video/5-hidden-cafes-in-kyoto',
      );
      expect(result.destination, 'Kyoto, Japan');
      expect(result.category, 'Food');
    });

    test('otherwise takes the title and handle from the link itself', () async {
      final result = await extractor.extract(
        'https://www.tiktok.com/@ramenhunter/video/hidden-ramen-bars-in-osaka',
      );
      expect(result.title, 'Hidden Ramen Bars in Osaka');
      expect(result.creator, '@ramenhunter');
    });

    test('gives placeable destinations coordinates, and regions none', () async {
      final kyoto = await extractor.extract(
        'https://www.tiktok.com/@wanderwithmia/video/5-hidden-cafes-in-kyoto',
      );
      expect(kyoto.hasCoordinates, isTrue);
      expect(kyoto.latitude, closeTo(35.0, 1.0));
      expect(kyoto.longitude, closeTo(135.8, 1.0));

      // "Top 10 Hostels in Southeast Asia" covers a region, not a point.
      final region = await extractor.extract(
        'https://www.tiktok.com/@budgetroamer/video/top-10-hostels-southeast-asia',
      );
      expect(region.destination, 'Southeast Asia');
      expect(region.hasCoordinates, isFalse);
    });

    test('always returns a category from the vocabulary', () async {
      for (final url in [
        'https://www.instagram.com/reel/one-two',
        'https://youtu.be/three-four',
        'https://example.com/five-six',
      ]) {
        final result = await extractor.extract(url);
        expect(NookCategories.all, contains(result.category));
      }
    });

    test('rejects something that is not a link', () {
      expect(
        () => extractor.extract('not a url'),
        throwsA(isA<ExtractionException>()),
      );
      expect(() => extractor.extract('   '), throwsA(isA<ExtractionException>()));
    });
  });
}
