import 'package:flutter/material.dart';

import 'nook_colors.dart';

/// The five colours a trip folder can be.
///
/// Five, not a wheel: the point is to tell four trips apart at a glance, not to
/// paint. Each is desaturated enough to sit under the warm background without
/// competing with the orange, which stays the only saturated colour.
///
/// Sand is the default because it is the tone already behind the app's cards,
/// so a trip nobody has customised still looks deliberate.
enum TripColor {
  sand('sand', Color(0xFFF7E7BE), Color(0xFF8A6B2F)),
  sky('sky', Color(0xFFD7E6F2), Color(0xFF3F6A8C)),
  fern('fern', Color(0xFFD9E8DA), Color(0xFF4A7351)),
  blush('blush', Color(0xFFF6DEDE), Color(0xFF9A5257)),
  lilac('lilac', Color(0xFFE3DEEF), Color(0xFF61568B));

  const TripColor(this.id, this.fill, this.ink);

  /// Stored in the database, so renaming the enum cannot silently repaint
  /// everyone's trips.
  final String id;

  /// The folder tile behind the icon.
  final Color fill;

  /// The icon and any text on [fill]. Darker than the fill rather than a
  /// shared grey, so each colour reads as one considered pair.
  final Color ink;

  static const fallback = TripColor.sand;

  /// Reads the stored value, tolerating null and anything unrecognised — an
  /// older row, or a colour removed in a later version.
  static TripColor parse(String? id) {
    for (final colour in values) {
      if (colour.id == id) return colour;
    }
    return fallback;
  }

  /// The colour a trip gets when nobody has chosen one. Spread by id rather
  /// than at random, so trips differ from each other and a trip keeps its
  /// colour across launches.
  static TripColor forId(int id) => values[id.abs() % values.length];

  /// What the picker calls it.
  String get label => switch (this) {
    TripColor.sand => 'Sand',
    TripColor.sky => 'Sky',
    TripColor.fern => 'Fern',
    TripColor.blush => 'Blush',
    TripColor.lilac => 'Lilac',
  };

  /// A hairline that belongs to the fill rather than the global border grey.
  Color get edge => Color.alphaBlend(ink.withValues(alpha: 0.18), fill);

  /// Selected state in the picker, which has to read on any of the five.
  static const selectedRing = NookColors.textPrimary;
}

/// The colour of a trip, from its stored choice or — failing that — its id.
///
/// Every screen that draws a folder goes through this, so a trip is the same
/// colour in the grid, on its own screen and in Recently Deleted.
TripColor tripColourOf({required int id, required String? colorId}) =>
    colorId == null ? TripColor.forId(id) : TripColor.parse(colorId);
