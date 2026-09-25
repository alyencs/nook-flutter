import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';
import '../theme/nook_spacing.dart';
import 'post_thumbnail.dart';

/// Flies a post's thumbnail from where it sits to the Trips tab.
///
/// Runs in the root overlay, above everything, so it survives the route being
/// popped underneath it — which is exactly what happens on save. Nothing waits
/// for it: the save has already been written by the time this starts, and the
/// flight is a statement about what happened, not part of doing it.
abstract final class SaveFlight {
  /// The Trips tab's centre on a 390pt-wide phone, measured from the bottom.
  /// The bottom bar is 68pt tall plus the safe area; the second of four tabs
  /// sits at three eighths of the width.
  static Offset _destination(Size screen, EdgeInsets padding) => Offset(
        screen.width * 0.375,
        screen.height - padding.bottom - 34,
      );

  /// [from] is the thumbnail's rect in global coordinates. Get it with a
  /// GlobalKey on the thumbnail — see the integration note below.
  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required String? thumbnailUrl,
  }) async {
    final media = MediaQuery.of(overlay.context);
    final to = _destination(media.size, media.padding);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Flight(
        from: from,
        to: to,
        thumbnailUrl: thumbnailUrl,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _Flight extends StatefulWidget {
  const _Flight({
    required this.from,
    required this.to,
    required this.thumbnailUrl,
    required this.onDone,
  });

  final Rect from;
  final Offset to;
  final String? thumbnailUrl;
  final VoidCallback onDone;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.slow,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _controller, curve: NookMotion.enter);

    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        // An arc rather than a straight line: it lifts slightly before it
        // falls, which reads as "picked up and put away" instead of "dragged".
        final x = widget.from.center.dx +
            (widget.to.dx - widget.from.center.dx) * v;
        final lift = -28 * (1 - (2 * v - 1) * (2 * v - 1));
        final y = widget.from.center.dy +
            (widget.to.dy - widget.from.center.dy) * v +
            lift;
        final size = widget.from.width * (1 - 0.72 * v);

        return Positioned(
          left: x - size / 2,
          top: y - size / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: v < 0.85 ? 1 : (1 - v) / 0.15,
              child: SizedBox(
                width: size,
                height: size * 9 / 16,
                child: PostThumbnail(
                  url: widget.thumbnailUrl,
                  radius: NookRadius.sm,
                  showGlyph: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}