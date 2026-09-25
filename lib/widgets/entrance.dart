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

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, widget.maxStaggered);
    Future<void>.delayed(NookMotion.stagger * steps, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: NookMotion.enter,
    );
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, NookMotion.enterOffset * (1 - curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}