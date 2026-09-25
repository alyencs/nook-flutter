import 'package:flutter/widgets.dart';

import '../theme/nook_motion.dart';

/// Scales its child down while it is held.
///
/// Wraps rather than replaces the gesture handling underneath: the child keeps
/// its own `InkWell`, its own `onTap`, and its own semantics. This only listens.
class PressEffect extends StatefulWidget {
  const PressEffect({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
  });

  final Widget child;
  final bool enabled;

  /// 0.97 for a full-width button. Go no lower than 0.94 or it reads as a
  /// wobble rather than a press.
  final double scale;

  @override
  State<PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<PressEffect> {
  bool _down = false;

  void _set(bool value) {
    if (!widget.enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Listener, not GestureDetector: it observes the pointer without
      // entering the gesture arena, so the InkWell inside still wins the tap.
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: NookMotion.fast,
        curve: NookMotion.press,
        child: widget.child,
      ),
    );
  }
}