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
  ///
  /// Raised from 900ms. At that length the card crossed most of the screen
  /// inside the front-loaded part of an ease-out curve, so the eye caught the
  /// start and the landing and very little in between. A delete and its mirror
  /// are the two animations in Nook with something to say, and the only ones
  /// worth a second and a half.
  static const deliberate = Duration(milliseconds: 1400);

  /// The curve for something travelling a long way that is meant to be read.
  ///
  /// [enter] is right for an arrival — fast, then settling — but on a journey
  /// this long it spends two thirds of the distance in the first third of the
  /// time, which is what made a 900ms flight feel like a 300ms one. This eases
  /// at both ends and holds a steady middle, so the middle is watchable.
  static const travel = Curves.easeInOutCubic;

  /// A folder opening, a tile settling. Between [normal] and [slow].
  static const settle = Duration(milliseconds: 420);

  /// How long the bar's ring takes to expand and fade after a flight lands.
  ///
  /// It is the fourth beat of a delete — the destination answering — so it runs
  /// after a 1400ms flight and needs to be long enough to still be arriving
  /// when the eye gets there.
  static const acknowledge = Duration(milliseconds: 700);

  /// The pause between a route transition finishing and a flight starting.
  ///
  /// Two page transitions run over the top of a flight that starts immediately,
  /// and the eye follows the page. This is the gap that lets the screen settle
  /// first, so the flight begins on a still background: beat one of four.
  static const beforeFlight = Duration(milliseconds: 460);

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
