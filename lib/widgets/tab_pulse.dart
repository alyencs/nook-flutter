import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';

/// A ring that expands once out of a bottom-bar tab.
///
/// The delete flight ends at the Profile tab; without this it ends *at*
/// nothing. The ring is the tab acknowledging the catch — the other half of
/// the sentence. One pulse, no repeat: it marks an event, it is not an
/// indicator.
abstract final class TabPulse {
  /// How long the ring takes to expand and fade.
  static const duration = Duration(milliseconds: 520);

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
        final radius = 14 + 34 * v;

        return Positioned(
          left: widget.centre.dx - radius,
          top: widget.centre.dy - radius,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - v).clamp(0.0, 1.0),
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // White, because the bar it sits on is the orange gradient.
                  border: Border.all(color: NookColors.surface, width: 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}