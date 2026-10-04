import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_motion.dart';

/// A ring that expands once out of a bottom-bar tab: the tab acknowledging the
/// delete flight that just landed on it. One pulse, no repeat — it marks an
/// event rather than indicating a state.
abstract final class TabPulse {
  /// How long the ring takes to expand and fade.
  static const duration = NookMotion.acknowledge;

  /// Draws a ring centred on [centre] in global coordinates.
  ///
  /// Fire and forget: it removes its own overlay entry when it finishes, and
  /// nothing should ever wait on it.
  static void at(OverlayState overlay, Offset centre) {
    late final OverlayEntry entry;
    var removed = false;
    entry = OverlayEntry(
      builder: (context) => _Pulse(
        centre: centre,
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

class _Pulse extends StatefulWidget {
  const _Pulse({required this.centre, required this.onDone});

  final Offset centre;
  final VoidCallback onDone;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TabPulse.duration,
  );

  /// Built once: a CurvedAnimation adds a status listener to its parent in the
  /// constructor, so one per build leaks one per build.
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    // catchError, because a controller disposed mid-pulse completes this
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
        // Sized to stay inside the 68pt bar rather than expanding over the
        // page above it.
        final radius = 12 + 22 * v;
        // Held at full strength for the first third: a linear fade leaves the
        // ring nearly transparent by the time it is big enough to notice.
        final opacity = v < 0.35 ? 1.0 : 1 - (v - 0.35) / 0.65;

        return Positioned(
          left: widget.centre.dx - radius,
          top: widget.centre.dy - radius,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // White, because the bar it sits on is the orange gradient.
                  border: Border.all(color: NookColors.surface, width: 3),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}