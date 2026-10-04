import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';
import 'flight.dart';

/// Flies a post's thumbnail to the Profile tab when it is deleted.
///
/// Profile rather than a trash icon, because that is where Recently Deleted
/// lives: the animation answers "where did that go".
///
/// Unlike the save flight this one is awaited, so the card leaves before the
/// row does and the two read as cause and effect. The write still happens if
/// the animation fails — see the call site.
abstract final class DeleteFlight {
  /// Profile is tab 3 of 4.
  static const tab = 3;

  /// The narrowest the card may set off at. Leaving from a 56pt thumbnail and
  /// shrinking puts most of the journey under 30pt across — smaller than the
  /// text it passes over.
  static const _minWidth = 132.0;

  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required String? thumbnailUrl,
  }) {
    final media = MediaQuery.of(overlay.context);
    return Flight.run(
      overlay,
      // Centred where the thumbnail was, so it still leaves from the post you
      // were looking at — just at a size that can be followed.
      from: Rect.fromCenter(
        center: from.center,
        width: from.width < _minWidth ? _minWidth : from.width,
        height: from.height,
      ),
      to: Flight.tabCentre(media.size, media.padding, tab),
      thumbnailUrl: thumbnailUrl,
      // Long, because this is the one animation whose job is to be followed:
      // an answer nobody sees is not an answer.
      duration: NookMotion.deliberate,
      // Ends tab-sized, so it reads as dropping into the tab rather than
      // stopping above it.
      endScale: 0.16,
      // A higher arc than the save flight. Saving puts something away;
      // deleting picks it up first, and the lift is what says so.
      lift: -64,
      opaque: true,
    );
  }
}

/// The reverse: a post coming back out of Recently Deleted.
///
/// The same arc as [DeleteFlight] read the other way, because delete and
/// restore are one interaction with a direction. This one grows a chip out of
/// the tab into the row's footprint, and bends the other way.
abstract final class RestoreFlight {
  /// The size of the chip as it leaves the tab, in logical pixels.
  static const _seed = 22.0;

  /// [to] is the restored row's rect in global coordinates, read from a
  /// GlobalKey before the list rebuilds without it.
  static Future<void> run(
    OverlayState overlay, {
    required Rect to,
    required String? thumbnailUrl,
  }) {
    final media = MediaQuery.of(overlay.context);
    final tabCentre = Flight.tabCentre(
      media.size,
      media.padding,
      DeleteFlight.tab,
    );

    return Flight.run(
      overlay,
      from: Rect.fromCenter(
        center: tabCentre,
        width: _seed,
        height: _seed,
      ),
      to: to.center,
      thumbnailUrl: thumbnailUrl,
      duration: NookMotion.deliberate,
      // Grows, but only to the height of the row it lands on: growing to the
      // row's full width drops a 16:9 card over half the list, which reads as
      // something opening rather than coming back to its place.
      endScale: (to.height * 16 / 9) / _seed,
      // The arc bends the other way, so the two are mirror images.
      lift: 64,
      opaque: true,
    );
  }
}
