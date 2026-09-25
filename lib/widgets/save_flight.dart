import 'package:flutter/material.dart';

import 'flight.dart';

/// Flies a post's thumbnail to the Trips tab when it is saved.
///
/// Nothing waits for it: the save has already been written by the time this
/// starts, and the flight is a statement about what happened, not part of
/// doing it.
abstract final class SaveFlight {
  /// Trips is tab 1 of 4.
  static const tab = 1;

  /// [from] is the thumbnail's rect in global coordinates, read from a
  /// GlobalKey on the thumbnail before the route is popped.
  ///
  /// Starts the flight and returns at once — deliberately not awaitable, so
  /// nothing downstream can end up waiting on an animation.
  static void run(
    OverlayState overlay, {
    required Rect from,
    required String? thumbnailUrl,
  }) {
    final media = MediaQuery.of(overlay.context);
    Flight.run(
      overlay,
      from: from,
      to: Flight.tabCentre(media.size, media.padding, tab),
      thumbnailUrl: thumbnailUrl,
    );
  }
}
