import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';

/// A folder that opens when it is tapped, before its screen arrives.
///
/// The lid tips back on an X rotation for the length of one tap and no longer.
/// Folders do not move on their own: a grid of six tiles breathing in place is
/// decoration, and Nook's rule is that motion means something happened.
///
/// The tap is run *after* the open completes, so the folder is visibly open
/// before the route changes under it. That ordering is the whole effect — run
/// them together and the animation is hidden by the page transition, which is
/// exactly the mistake the delete flight was making.
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

  @override
  void dispose() {
    (_t as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    // A controller disposed mid-open completes with TickerCanceled.
    try {
      await _controller.forward();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    widget.onTap();
    // Closed again, for when the user comes back to this list.
    _controller.reverse();
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
              // A little perspective, so the tip reads as a lid opening rather
              // than the tile shearing.
              ..setEntry(3, 2, 0.0015)
              ..rotateX(-0.22 * v)
              // translateByDouble, not translate: the Vector-math overload is
              // deprecated in current Flutter and raises an analyzer info.
              ..translateByDouble(0.0, -4.0 * v, 0.0, 1.0),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A folder that springs once, when it first appears.
///
/// For a trip that was just created or just restored — the two moments when a
/// folder is new to the screen and worth pointing at. It plays once on mount
/// and never again.
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
