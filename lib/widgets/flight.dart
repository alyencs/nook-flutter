import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_colors.dart';
import 'post_thumbnail.dart';

/// A post's thumbnail travelling from where it was to where it now lives.
///
/// One arc shared by saving and deleting: the same sentence with a different
/// destination. Saving points at Trips, deleting at Profile, because that is
/// where Recently Deleted is.
///
/// Runs in the root overlay so it survives the route being popped underneath
/// it, which is what happens in both flows.
abstract final class Flight {
  /// The centre of tab [index] of four, and the vertical middle of the
  /// 68pt-tall bar above the safe area. Derived from `NookBottomNav`'s equal
  /// shares rather than measured off a screenshot.
  static Offset tabCentre(Size screen, EdgeInsets padding, int index) => Offset(
    screen.width * ((index + 0.5) / 4),
    screen.height - padding.bottom - 34,
  );

  /// Starts the flight and returns a future that completes when it lands.
  ///
  /// Only deleting awaits it, so the card is visibly gone before the row
  /// disappears from under it. Saving does not: the row is already written.
  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required Offset to,
    required String? thumbnailUrl,
    Duration duration = NookMotion.slow,
    double endScale = 0.28,
    double lift = -28,
    bool opaque = false,
  }) {
    final done = Completer<void>();

    late final OverlayEntry entry;
    var removed = false;
    entry = OverlayEntry(
      builder: (context) => _Flight(
        from: from,
        to: to,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        endScale: endScale,
        lift: lift,
        opaque: opaque,
        // Guarded: whenComplete also fires when the controller is disposed
        // mid-flight, and removing an entry twice trips an assertion.
        onDone: () {
          if (removed) return;
          removed = true;
          entry.remove();
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    overlay.insert(entry);
    return done.future;
  }
}

class _Flight extends StatefulWidget {
  const _Flight({
    required this.from,
    required this.to,
    required this.thumbnailUrl,
    required this.onDone,
    required this.duration,
    required this.endScale,
    required this.lift,
    required this.opaque,
  });

  final Rect from;
  final Offset to;
  final String? thumbnailUrl;
  final VoidCallback onDone;

  /// How long the whole journey takes.
  final Duration duration;

  /// The fraction of its starting width it ends at.
  final double endScale;

  /// The height of the arc at its midpoint, in logical pixels. Negative lifts.
  final double lift;

  /// Paints a solid card behind the thumbnail, so the thing travelling is
  /// visible even when the image never loads.
  final bool opaque;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// Built once: a CurvedAnimation registers a status listener on its parent,
  /// so one per build leaks one per build.
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: NookMotion.travel,
  );

  @override
  void initState() {
    super.initState();
    // catchError, because a controller disposed mid-flight completes this
    // future with TickerCanceled, which is otherwise an unhandled rejection.
    _controller.forward().whenComplete(widget.onDone).catchError((_) {});
  }

  @override
  void dispose() {
    (_t as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final v = _t.value;
        // An arc rather than a straight line: it lifts before it falls, which
        // reads as "picked up and put away" instead of "dragged".
        final x =
            widget.from.center.dx + (widget.to.dx - widget.from.center.dx) * v;
        final arc = widget.lift * (1 - (2 * v - 1) * (2 * v - 1));
        final y =
            widget.from.center.dy +
            (widget.to.dy - widget.from.center.dy) * v +
            arc;
        final size =
            widget.from.width * (1 - (1 - widget.endScale) * v);
        final height = size * 9 / 16;

        return Positioned(
          left: x - size / 2,
          top: y - height / 2,
          child: IgnorePointer(
            child: Opacity(
              // Fades only over the last 8%, so the journey ends at the tab
              // rather than a tab's height short of it.
              opacity: (v < 0.92 ? 1.0 : (1 - v) / 0.08).clamp(0.0, 1.0),
              child: Container(
                width: size,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NookRadius.sm),
                  // Opaque, with the same 1.5pt border every other card uses:
                  // a pale card on a cream background is a rumour, and this one
                  // has to stay legible while it crosses them.
                  color: widget.opaque ? NookColors.surface : null,
                  border: widget.opaque
                      ? Border.all(color: NookColors.textPrimary, width: 1.5)
                      : null,
                  boxShadow: widget.opaque
                      ? const [
                          BoxShadow(
                            color: Color(0x452E2E2E),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                // The glyph stays on, so a post with no thumbnail does not fly
                // an empty box across the screen.
                child: PostThumbnail(
                  url: widget.thumbnailUrl,
                  radius: NookRadius.sm,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
