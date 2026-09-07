import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/nook_spacing.dart';
import 'thumb_placeholder.dart';

/// A saved post's preview image, or the drawn placeholder when there is none.
///
/// Two things make this more than a plain [Image.network]:
///
/// * On the web, CanvasKit fetches images over HTTP, so a host that does not
///   send CORS headers fails. [WebHtmlElementStrategy.prefer] renders through a
///   plain `<img>` element instead, which is not subject to that check — the
///   same way a thumbnail on any ordinary web page loads.
/// * A thumbnail can 404 or go away long after it was saved, so a failure falls
///   back to the placeholder rather than showing a broken image.
class PostThumbnail extends StatelessWidget {
  const PostThumbnail({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.aspectRatio,
    this.radius = NookRadius.sm,
    this.showGlyph = true,
  });

  final String? url;
  final double? width;
  final double? height;
  final double? aspectRatio;
  final double radius;
  final bool showGlyph;

  @override
  Widget build(BuildContext context) {
    final placeholder = ThumbPlaceholder(
      width: width,
      height: height,
      aspectRatio: aspectRatio,
      radius: radius,
      showGlyph: showGlyph,
    );

    final source = url;
    if (source == null || source.isEmpty) return placeholder;

    Widget image = Image.network(
      source,
      width: width,
      height: height,
      fit: BoxFit.cover,
      webHtmlElementStrategy:
          kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
      errorBuilder: (context, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );

    if (aspectRatio != null) {
      image = AspectRatio(aspectRatio: aspectRatio!, child: image);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
  }
}
