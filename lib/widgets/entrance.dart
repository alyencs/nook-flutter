import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/nook_motion.dart';

/// Fades and lifts its child in, once, when it first appears.
///
/// [index] staggers a list: pass the item's position and each one starts a
/// beat after the one before. Cap the stagger — past about six items the last
/// card arrives long after the screen looks finished.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.maxStaggered = 6,
  });

  final Widget child;
  final int index;
  final int maxStaggered;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.normal,
  );

  /// Built once, not per build: CurvedAnimation adds a status listener to its
  /// parent in the constructor, so one per frame leaks one listener per frame.
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: NookMotion.enter,
  );

  /// Held so a widget disposed mid-stagger cancels its own start.
  Timer? _start;

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, widget.maxStaggered);
    if (steps == 0) {
      _controller.forward();
      return;
    }
    _start = Timer(NookMotion.stagger * steps, _controller.forward);
  }

  @override
  void dispose() {
    // Cancelled rather than guarded with `mounted`: an uncancelled timer keeps
    // a widget test alive past its last frame, and fires into a disposed
    // controller after a hot restart.
    _start?.cancel();
    (_curve as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, NookMotion.enterOffset * (1 - _curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
