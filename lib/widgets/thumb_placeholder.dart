import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';

/// The thumbnail placeholder, drawn exactly as the mockup does: a pale panel
/// crossed corner to corner, with a small image glyph in the top-left.
///
/// This is not a stand-in for a real thumbnail that never arrived. A browser
/// cannot fetch a TikTok or Instagram preview image directly (CORS), so no
/// build of this app has one, and pretending otherwise would mean shipping a
/// broken image icon on every card.
class ThumbPlaceholder extends StatelessWidget {
  const ThumbPlaceholder({
    super.key,
    this.width,
    this.height,
    this.radius = NookRadius.sm,
    this.showGlyph = true,
    this.aspectRatio,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool showGlyph;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    Widget panel = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NookColors.placeholder,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: CustomPaint(painter: _CrossPainter(), child: const SizedBox.expand()),
    );

    if (aspectRatio != null) {
      panel = AspectRatio(aspectRatio: aspectRatio!, child: panel);
    }

    if (!showGlyph) return panel;

    return Stack(
      children: [
        panel,
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: NookColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 14,
              color: NookColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NookColors.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
