import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/platform_from_url.dart';
import 'package:nook/share/shared_link.dart';
import 'package:nook/widgets/open_original.dart';

/// The two new ways in and out of a saved post.
void main() {
  group('a link shared from another app', () {
    test('is found inside the sentence a share sheet wraps it in', () {
      expect(
        SharedLink.firstLinkIn(
          'Check this out! https://vm.tiktok.com/ZSABCdefg/ '
          'on TikTok',
        ),
        'https://vm.tiktok.com/ZSABCdefg/',
      );
    });

    test('loses the punctuation that belongs to the sentence', () {
      expect(
        SharedLink.firstLinkIn('Look at this (https://youtu.be/Sf9ihvL0Usk).'),
        'https://youtu.be/Sf9ihvL0Usk',
      );
    });

    test('survives a newline between the text and the link', () {
      expect(
        SharedLink.firstLinkIn('Rainy Day in Osaka\nhttps://youtu.be/abc123'),
        'https://youtu.be/abc123',
      );
    });

    test('is null when the share carried no link', () {
      expect(SharedLink.firstLinkIn('just some text'), isNull);
      expect(SharedLink.firstLinkIn(''), isNull);
      expect(SharedLink.firstLinkIn(null), isNull);
    });

    test('takes the first link when a share carries several', () {
      expect(
        SharedLink.firstLinkIn('https://a.example/1 and https://b.example/2'),
        'https://a.example/1',
      );
    });
  });

  group('opening the original post', () {
    test('a saved link is openable', () {
      expect(
        OpenOriginal.isAvailable('https://www.tiktok.com/@mia/video/123'),
        isTrue,
      );
    });

    test('a note, a blank and a malformed link are not', () {
      expect(OpenOriginal.isAvailable(null), isFalse);
      expect(OpenOriginal.isAvailable(''), isFalse);
      expect(OpenOriginal.isAvailable('   '), isFalse);
      expect(OpenOriginal.isAvailable('not a url'), isFalse);
      expect(OpenOriginal.isAvailable('/relative/path'), isFalse);
    });

    test('a non-web scheme is refused', () {
      // Nothing should be able to talk Nook into launching an arbitrary
      // scheme through a saved row.
      expect(OpenOriginal.isAvailable('javascript:alert(1)'), isFalse);
      expect(OpenOriginal.isAvailable('file:///etc/passwd'), isFalse);
    });

    test('the label names the platform it will open', () {
      expect(
        OpenOriginal.labelFor('https://youtu.be/x', NookPlatform.youtube),
        'Open in YouTube',
      );
      expect(
        OpenOriginal.labelFor('https://example.com/x', NookPlatform.other),
        'Open original post',
      );
    });
  });
}
