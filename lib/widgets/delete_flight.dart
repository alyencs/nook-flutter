import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';
import 'flight.dart';

/// Flies a post's thumbnail to the Profile tab when it is deleted.
///
/// Profile rather than a trash icon, because Profile is where Recently Deleted
/// lives. The animation is not decoration on the word "deleted" — it is the
/// answer to "where did that go", pointing at the place the post can be found
/// and restored from.
///
/// Unlike the save flight this one is awaited. The row vanishing from under a
/// card that is still sitting there reads as a glitch; letting the card leave
/// first and then committing the delete reads as cause and effect. The write
/// still happens if the animation fails — see the call site.
abstract final class DeleteFlight {
  /// Profile is tab 3 of 4.
  static const tab = 3;

  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required String? thumbnailUrl,
  }) {
    final media = MediaQuery.of(overlay.context);
    return Flight.run(
      overlay,
      from: from,
      to: Flight.tabCentre(media.size, media.padding, tab),
      thumbnailUrl: thumbnailUrl,
      // Nine hundred milliseconds, not four hundred. This is the one animation
      // whose whole job is to be followed: it answers "where did my post go",
      // and an answer nobody sees is not an answer.
      duration: NookMotion.deliberate,
      // Ends at 18% rather than 28%, so it reads as dropping *into* the tab
      // rather than stopping above it.
      endScale: 0.18,
      // A higher arc than the save flight. Saving puts something away;
      // deleting picks it up first, and the lift is what says so.
      lift: -64,
      opaque: true,
    );
  }
}

/// The reverse: a post coming back out of Recently Deleted.
///
/// Deliberately the same arc as [DeleteFlight] read the other way. Delete and
/// restore are one interaction with a direction; two unrelated motions would
/// make them look like two unrelated features.
///
/// Where the delete flight shrinks a card into a tab, this one grows a chip
/// out of the tab into the row's own footprint, and bends the other way.
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
      // Larger than it started: this one grows, which is the whole point.
      endScale: to.width / _seed,
      // The arc bends the other way, so the two are mirror images.
      lift: 64,
      opaque: true,
    );
  }
}
