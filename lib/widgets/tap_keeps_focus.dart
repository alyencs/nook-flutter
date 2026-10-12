import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Holds a text field's focus when it is tapped while already focused.
///
/// The app is drawn inside the preview, which scales it to fit the window. A
/// tap on a field that already holds focus is resolved through that scale to
/// place the caret, and under the scale it resolves to nothing: the field
/// drops its focus and anything typed afterwards is discarded. Tapping again
/// does not recover it, because the second tap is the same arithmetic on the
/// same field — only tapping somewhere else first clears the state.
///
/// From the other side of the screen that is a form that stops working as
/// soon as you touch it twice, with nothing on screen to say why.
///
/// This watches for exactly that: a field that had focus when the tap landed
/// and has lost it a moment later, with nothing else having taken it. In that
/// one case the focus is handed straight back. A tap that legitimately moves
/// focus elsewhere gives it to another node, so it is left alone.
///
/// **Pointer input only.** The repair is a mouse-pointer fix for a transform
/// that only a mouse pointer meets, and running it on a finger breaks the
/// things a finger is for. Dropping focus on a touch device closes the soft
/// keyboard, and taking it back a frame later reopens it, so a tap reads as a
/// keyboard that flickers and goes away. Worse, the native selection toolbar —
/// the one holding Paste — is dismissed the moment the field loses focus, so a
/// long press could never reach it. Touch is therefore left entirely alone:
/// the platform's own handling of tap, long press, selection and paste is
/// already correct, and this widget's job is to not be in its way.
class TapKeepsFocus extends StatefulWidget {
  const TapKeepsFocus({
    super.key,
    required this.focusNode,
    required this.child,
  });

  final FocusNode focusNode;
  final Widget child;

  @override
  State<TapKeepsFocus> createState() => _TapKeepsFocusState();
}

class _TapKeepsFocusState extends State<TapKeepsFocus> {
  /// Checked twice: the focus is dropped a frame or two after the tap, and
  /// how many depends on what else is rebuilding. Both are short enough that
  /// the caret does not visibly flicker.
  static const _checks = [Duration(milliseconds: 120), Duration(milliseconds: 360)];

  final _timers = <Timer>[];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    // A finger is handled by the platform, correctly, and must not be
    // interrupted: see the note on the class.
    if (event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return;
    }

    // Only a tap that lands on an already-focused field can hit this; a tap
    // meant for another field lands on that field's own listener instead, so
    // there is no case here where focus is being moved away on purpose.
    if (!widget.focusNode.hasFocus) return;
    for (final t in _timers) {
      t.cancel();
    }
    _timers
      ..clear()
      ..addAll([
        for (final after in _checks)
          Timer(after, () {
            if (!mounted) return;
            // Dropping the node and taking it again, rather than asking for
            // focus it believes it already has: the Dart node can still read
            // as focused while the engine's editing connection has gone, and
            // in that state a bare requestFocus is a no-op.
            widget.focusNode.unfocus();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.focusNode.requestFocus();
            });
          }),
      ]);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Behind the field's own gesture handling, not in front of it: this
      // only observes, and must never be the reason a tap is swallowed.
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _onPointerDown,
      child: widget.child,
    );
  }
}
