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

  /// Something crossing the whole screen that the user is meant to follow.
  ///
  /// Long enough to read as travel rather than a flicker. The save flight stays
  /// at [slow] — it confirms something already done — but a delete has to be
  /// watched, because it is answering "where did it go".
  static const deliberate = Duration(milliseconds: 900);

  /// A folder opening, a tile settling. Between [normal] and [slow].
  static const settle = Duration(milliseconds: 340);

  /// Springy, for something that arrives and should feel physical. Used by the
  /// folder lid and the logo pieces; never by anything that travels far, where
  /// an overshoot reads as a mistake.
  static const arrive = Curves.easeOutBack;

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
