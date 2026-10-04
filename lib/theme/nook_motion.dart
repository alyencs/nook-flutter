import 'package:flutter/widgets.dart';

/// Durations and curves, in one place, so motion reads as one system.
///
/// Quick and slightly eased-out — things arrive and settle rather than bounce.
/// The everyday durations stay at or under 420ms, because an animation you
/// notice waiting for is a slower app.
abstract final class NookMotion {
  /// A press, a toggle, a ripple. Barely perceived.
  static const fast = Duration(milliseconds: 140);

  /// The default: entrances, fades, a page change.
  static const normal = Duration(milliseconds: 260);

  /// Something travelling across the screen.
  static const slow = Duration(milliseconds: 420);

  /// Something crossing the whole screen that the user is meant to follow.
  ///
  /// The save flight stays at [slow] because it confirms something already
  /// done; a delete has to be watched, because it answers "where did it go".
  static const deliberate = Duration(milliseconds: 1400);

  /// For something travelling a long way that is meant to be read. [enter]
  /// spends two thirds of the distance in the first third of the time; this
  /// eases at both ends and holds a steady middle, so the middle is watchable.
  static const travel = Curves.easeInOutCubic;

  /// A folder opening, a tile settling. Between [normal] and [slow].
  static const settle = Duration(milliseconds: 420);

  /// How long the bar's ring takes to expand and fade after a flight lands —
  /// the destination answering, so it has to still be arriving when the eye
  /// gets there.
  static const acknowledge = Duration(milliseconds: 700);

  /// The pause between a route transition finishing and a flight starting. The
  /// eye follows the page, so the flight has to begin on a still background.
  static const beforeFlight = Duration(milliseconds: 460);

  /// Springy, for something that arrives and should feel physical. Never for
  /// anything that travels far, where an overshoot reads as a mistake.
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
