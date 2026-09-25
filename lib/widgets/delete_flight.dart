import 'package:flutter/material.dart';

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
    );
  }
}
