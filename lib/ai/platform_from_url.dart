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

  static String fromUrl(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.contains('tiktok')) return tiktok;
    if (host.contains('instagram')) return instagram;
    if (host.contains('facebook') || host.contains('fb.watch')) return facebook;
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
