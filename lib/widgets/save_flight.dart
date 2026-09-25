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
  /// The Trips tab's centre, derived rather than measured: `NookBottomNav`
  /// lays four tabs out in equal shares, so tab 1 of 4 sits at (1 + 0.5) / 4 of
  /// the width, and its 68pt-tall bar puts the centre 34pt above the safe area.
  static Offset _destination(Size screen, EdgeInsets padding) =>
      Offset(screen.width * 0.375, screen.height - padding.bottom - 34);

  /// [from] is the thumbnail's rect in global coordinates, read from a
  /// GlobalKey on the thumbnail before the route is popped.
  ///
  /// Starts the flight and returns at once — it is deliberately not awaitable.
  /// The save is already committed by the time this is called, so nothing
  /// downstream should be waiting on an animation.
  static void run(
    OverlayState overlay, {
    required Rect from,
    required String? thumbnailUrl,
  }) {
    final media = MediaQuery.of(overlay.context);
    final to = _destination(media.size, media.padding);

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
        },
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
