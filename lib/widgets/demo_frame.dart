import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';

/// Holds the app at phone proportions when the window is wider than a phone.
///
/// Nook is laid out for a phone. Opened on a desktop browser — which is what a
/// live link is — a 390pt design stretched across 1600pt reads as broken, so on
/// a wide window the app is drawn inside a phone-sized panel and the rest of
/// the page is left as background.
///
/// Deliberately inert. It is a [Center], a [SizedBox] and a border, and that is
/// the whole of it: no overlay, no second [Navigator], no [IgnorePointer], no
/// scale. Anything of that kind sits between a finger and a button, and on a
/// deployed build there is no console to find out why a tap did nothing.
///
/// Below [minimumFramedWidth] there is nothing to frame — a phone, or a window
/// the size of one — and the app is handed the window whole.
class DemoFrame extends StatelessWidget {
  const DemoFrame({super.key, required this.child});

  final Widget child;

  /// The width of the screen the app is designed against.
  static const double phoneWidth = 390;

  /// The height of that screen.
  static const double phoneHeight = 844;

  /// The screen the app is designed against.
  static const Size phone = Size(phoneWidth, phoneHeight);

  /// The clear space the panel needs on each side before framing is worth it.
  static const double margin = 24;

  /// Narrower than this and the window is already phone-shaped.
  static const double minimumFramedWidth = phoneWidth + 2 * margin;

  /// Shorter than this and the panel would be a letterbox, not a phone.
  static const double minimumFramedHeight = 480;

  /// Whether a window of this size gets the frame.
  static bool framedAt(Size size) =>
      size.width >= minimumFramedWidth && size.height >= minimumFramedHeight;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!framedAt(media.size)) return child;

    // As tall as the design, or as tall as the window allows. A short window
    // gets a shorter phone rather than one cropped off the bottom.
    final height = math.min(phone.height, media.size.height - 2 * margin);
    final size = Size(phone.width, height);

    return ColoredBox(
      color: NookColors.placeholder,
      child: Center(
        child: SizedBox.fromSize(
          size: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(blurRadius: 24, color: Color(0x1A2E2E2E)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: MediaQuery(
                // The app inside is told it is on a phone, so `MediaQuery.of`
                // answers with the panel rather than the browser window. The
                // device paddings go: there is no notch on a page.
                data: media.copyWith(
                  size: size,
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
