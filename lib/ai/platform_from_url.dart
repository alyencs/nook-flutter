/// Which platform a link came from.
///
/// Parsed from the URL host rather than asked of the model: it is free, instant
/// and cannot be got wrong by a language model having an off day.
abstract final class NookPlatform {
  static const tiktok = 'tiktok';
  static const instagram = 'instagram';
  static const facebook = 'facebook';
  static const youtube = 'youtube';
  static const other = 'other';

  /// The four the Paste Link screen lists as supported.
  static const supported = <String>[tiktok, instagram, facebook, youtube];

  /// A pasted link, made absolute.
  ///
  /// A share sheet or a keyboard suggestion often hands over
  /// `www.tiktok.com/@u/video/123` with no scheme. `Uri.parse` reads that as a
  /// path with an empty host, so every host test below misses and a perfectly
  /// ordinary TikTok link is treated as belonging to no platform. The same
  /// missing scheme later stops the saved post being reopened, because that
  /// needs an `http`/`https` URL.
  ///
  /// Only text that already looks like a host is touched — something with a
  /// dot before the first slash — so a typed note is left as it is rather than
  /// being dressed up as a URL.
  static String normalise(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (Uri.tryParse(trimmed)?.hasScheme ?? false) return trimmed;
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    final firstSegment = trimmed.split('/').first;
    if (!firstSegment.contains('.')) return trimmed;
    return 'https://$trimmed';
  }

  static String fromUrl(String url) {
    final host = Uri.tryParse(normalise(url))?.host.toLowerCase() ?? '';
    if (host.contains('tiktok')) return tiktok;
    // instagr.am and fb.me are the platforms' own short domains, and neither
    // carries the full name that the checks above and below look for.
    if (host.contains('instagram') || host.contains('instagr.am')) {
      return instagram;
    }
    if (host.contains('facebook') ||
        host.contains('fb.watch') ||
        host.contains('fb.me')) {
      return facebook;
    }
    if (host.contains('youtube') || host.contains('youtu.be')) return youtube;
    return other;
  }

  static String label(String platform) => switch (platform) {
    tiktok => 'TikTok',
    instagram => 'Instagram',
    facebook => 'Facebook',
    youtube => 'YouTube',
    _ => 'Link',
  };
}
