import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';
import '../theme/nook_spacing.dart';
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
  }) {
    final done = Completer<void>();

    late final OverlayEntry entry;
    var removed = false;
    entry = OverlayEntry(
      builder: (context) => _Flight(
        from: from,
        to: to,
        thumbnailUrl: thumbnailUrl,
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
  });

  final Rect from;
  final Offset to;
  final String? thumbnailUrl;
  final VoidCallback onDone;

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
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: NookMotion.enter,
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
        // An arc rather than a straight line: it lifts slightly before it
        // falls, which reads as "picked up and put away" instead of "dragged".
        final x =
            widget.from.center.dx + (widget.to.dx - widget.from.center.dx) * v;
        final lift = -28 * (1 - (2 * v - 1) * (2 * v - 1));
        final y =
            widget.from.center.dy +
            (widget.to.dy - widget.from.center.dy) * v +
            lift;
        final size = widget.from.width * (1 - 0.72 * v);
        final height = size * 9 / 16;

        return Positioned(
          left: x - size / 2,
          top: y - height / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: (v < 0.85 ? 1.0 : (1 - v) / 0.15).clamp(0.0, 1.0),
              child: SizedBox(
                width: size,
                height: height,
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
