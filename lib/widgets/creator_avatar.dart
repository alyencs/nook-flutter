import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_typography.dart';

/// The person who made a post, as a circle.
///
/// Draws the creator's real profile picture when the platform published one,
/// and their initial when it did not — which is most of the time, and on
/// purpose.
///
/// **Why this is usually an initial.** Of the four platforms Nook reads, only
/// YouTube exposes a creator's avatar through a route the app can legitimately
/// use, and only when a `YOUTUBE_API_KEY` is configured: the Data API will give
/// a channel's thumbnails if asked for them by channel id. TikTok's oEmbed
/// returns the author's name and page and nothing else about them. Instagram
/// and Facebook return the same through the Graph API; a profile picture there
/// needs a different permission, and for a person rather than a page, their
/// consent.
///
/// So the choice was between an initial and inventing something. Nothing here
/// derives a face from a handle, picks a stock portrait, or generates an image:
/// a missing avatar is drawn as a missing avatar.
class CreatorAvatar extends StatelessWidget {
  const CreatorAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 32,
  });

  /// The display name, used for the initial when there is no picture.
  final String? name;

  /// The picture the platform published, if it published one.
  final String? avatarUrl;

  final double size;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final circle = BoxDecoration(
      color: NookColors.placeholder,
      shape: BoxShape.circle,
      border: Border.all(color: NookColors.border),
    );

    Widget fallback() => Container(
      width: size,
      height: size,
      decoration: circle,
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: NookType.caption.copyWith(
          color: NookColors.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );

    if (url == null || url.isEmpty) return fallback();

    return Container(
      width: size,
      height: size,
      decoration: circle,
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // The same reason PostThumbnail does this: on the web CanvasKit fetches
        // the bytes over HTTP, so a host without CORS headers fails. An <img>
        // element is not subject to that check.
        webHtmlElementStrategy: kIsWeb
            ? WebHtmlElementStrategy.prefer
            : WebHtmlElementStrategy.never,
        errorBuilder: (context, _, _) => fallback(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback(),
      ),
    );
  }

  /// The first letter of the creator's name, with the `@` of a handle skipped.
  String get _initial {
    final source = name?.trim().replaceFirst(RegExp(r'^@'), '') ?? '';
    if (source.isEmpty) return '·';
    return source.characters.first.toUpperCase();
  }
}
