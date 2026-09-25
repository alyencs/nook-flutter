import 'package:flutter/widgets.dart';

/// Durations and curves, in one place.
///
/// The same reasoning as `NookSpacing` and `NookType`: a dozen screens each
/// picking their own 180ms-ish easing is how motion stops reading as one system.
///
/// Nook's motion is quick and slightly eased-out — things arrive and settle
/// rather than bounce. Nothing here is longer than 420ms, because an animation
/// you notice waiting for is a slower app.
abstract final class NookMotion {
  /// A press, a toggle, a ripple. Barely perceived.
  static const fast = Duration(milliseconds: 140);

  /// The default: entrances, fades, a page change.
  static const normal = Duration(milliseconds: 260);

  /// Something travelling across the screen.
  static const slow = Duration(milliseconds: 420);

  /// Arrivals. Fast at the start, settling at the end.
  static const enter = Curves.easeOutCubic;

  /// Departures.
  static const exit = Curves.easeInCubic;

  /// A press going down and coming back.
  static const press = Curves.easeOut;

  /// The gap between consecutive items in a staggered list.
  static const stagger = Duration(milliseconds: 45);

  /// How far a card travels as it fades in, in logical pixels.
  static const enterOffset = 14.0;
}