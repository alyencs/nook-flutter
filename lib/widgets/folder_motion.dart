import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';

/// A folder that opens when it is tapped, before its screen arrives.
///
/// The lid tips back for the length of one tap and no longer; folders do not
/// move on their own.
///
/// The tap runs *after* the open completes, so the folder is visibly open
/// before the route changes under it. Run together, the page transition hides
/// the animation entirely.
class FolderOpen extends StatefulWidget {
  const FolderOpen({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<FolderOpen> createState() => _FolderOpenState();
}

class _FolderOpenState extends State<FolderOpen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.settle,
  );

  /// Built once: a CurvedAnimation adds a status listener to its parent in the
  /// constructor, so one per build leaks one per build.
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: NookMotion.enter,
  );

  /// True from this folder's tap until its lid is back down, so a second tap
  /// during the open is ignored rather than restarting it.
  ///
  /// One per folder, not one per app: shared, a single lid part-way through its
  /// tip silences every other folder on every screen.
  bool _opening = false;

  /// The wait between the lid lifting and the tap running.
  ///
  /// A timer rather than the controller's future: a ticker is muted while its
  /// screen sits under another route, and a muted ticker neither ticks nor
  /// cancels, so anything awaiting one waits for ever.
  Timer? _run;

  @override
  void dispose() {
    // Cancelled, so tearing the tree down takes the pending tap with it.
    _run?.cancel();
    (_t as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    if (_opening) return;
    _opening = true;
    _controller.forward(from: 0);
    _run = Timer(NookMotion.settle, () {
      _opening = false;
      if (!mounted) return;
      // Another screen arrived while the lid was lifting — a second tap landed
      // on something that navigates — so this tap is stale. The folder closes
      // again rather than pushing a route on top of wherever the user now is.
      if (ModalRoute.of(context)?.isCurrent == false) {
        _controller.value = 0;
        return;
      }
      widget.onTap();
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      // The child paints its own surface, so the gesture needs its own
      // hit area rather than deferring to a transparent parent.
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          final v = _t.value;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              // Perspective, so the tip reads as a lid opening rather than the
              // tile shearing. On a card 72pt tall a shallower value moves the
              // top edge about two pixels, which is invisible.
              ..setEntry(3, 2, 0.0028)
              ..rotateX(-0.42 * v)
              // Lifted off the grid and brought closer, so it leaves the page
              // rather than folding into it. translateByDouble, because the
              // Vector-math overload is deprecated.
              ..translateByDouble(0.0, -10.0 * v, 0.0, 1.0)
              ..scaleByDouble(
                1 + 0.06 * v,
                1 + 0.06 * v,
                1.0,
                1.0,
              ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A folder that springs once, when it first appears: a trip just created or
/// just restored. Plays on mount and never again.
class FolderArrive extends StatefulWidget {
  const FolderArrive({super.key, required this.child});

  final Widget child;

  @override
  State<FolderArrive> createState() => _FolderArriveState();
}

class _FolderArriveState extends State<FolderArrive>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.settle,
  )..forward();

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: NookMotion.arrive,
  );

  @override
  void dispose() {
    (_t as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _t, child: widget.child);
  }
}
