import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_colors.dart';
import 'post_thumbnail.dart';

/// A post's thumbnail travelling from where it was to where it now lives.
///
/// Extracted from the save animation so that deleting can say the same kind of
/// thing without a second copy of the arc maths. Both are the same sentence
/// with a different destination: *this went there*. Saving points at Trips;
/// deleting points at Profile, because that is where Recently Deleted is, so
/// the animation answers "where did it go" rather than merely "it is gone".
///
/// Runs in the root overlay, above everything, so it survives the route being
/// popped underneath it — which is what happens in both flows.
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
  /// Awaiting is optional and only one caller does it: deleting waits so the
  /// card is visibly gone before the row disappears from under it. Saving does
  /// not, because the row is already written by then.
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
    duration: NookMotion.slow,
  );

  /// Built once: a CurvedAnimation registers a status listener on its parent,
  /// so one per build leaks one per build.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
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
              opacity: (v < 0.85 ? 1.0 : (1 - v) / 0.15).clamp(0.0, 1.0),
              child: Container(
                width: size,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NookRadius.sm),
                  // An opaque card with a shadow. The old version flew a
                  // transparent placeholder across a pale background, which is
                  // most of why nobody saw it.
                  color: widget.opaque ? NookColors.surface : null,
                  boxShadow: widget.opaque
                      ? const [
                          BoxShadow(
                            color: Color(0x332E2E2E),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                // The glyph stays on: a post with no thumbnail, or one whose
                // image fails to load, otherwise flies an empty box across the
                // screen — an animation that runs and says nothing.
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
