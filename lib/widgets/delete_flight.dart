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

  /// The narrowest the card is allowed to set off at.
  ///
  /// It leaves from a 56pt thumbnail, and a card that starts at 56 and shrinks
  /// to a fifth of that spends most of its journey under 30pt across — a speck
  /// on a cream background. Measured off a recording of the real thing: at
  /// mid-flight the old card was about 30x17, which is smaller than the text
  /// it was passing over.
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
      // Nine hundred milliseconds, not four hundred. This is the one animation
      // whose whole job is to be followed: it answers "where did my post go",
      // and an answer nobody sees is not an answer.
      duration: NookMotion.deliberate,
      // Ends at 16% of that, so it reads as dropping *into* the tab rather
      // than stopping above it: 132 x 74 at the start, about 21 x 12 as it
      // arrives, which is tab-sized.
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
      // Larger than it started: this one grows, which is the whole point —
      // but only to the height of the row it is landing on. Growing to the
      // row's full *width* made a 16:9 card almost 200pt tall drop over a
      // 68pt row, covering half the list: that reads as something opening,
      // not as something coming back to its place.
      endScale: (to.height * 16 / 9) / _seed,
      // The arc bends the other way, so the two are mirror images.
      lift: 64,
      opaque: true,
    );
  }
}
