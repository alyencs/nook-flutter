/// The design system's spacing rule, and the radius scale the mockup draws.
abstract final class NookSpacing {
  /// Between related items.
  static const tight = 8.0;

  /// Between sections.
  static const section = 16.0;

  /// Screen edge padding. Measured off the mockup and unchanged: a button
  /// spans 342 of the 390pt frame, which is exactly 24 either side.
  static const screenEdge = 24.0;

  /// Between major blocks on a screen.
  ///
  /// Vertical only. The screen edge was doing this job too, which is what made
  /// the screens taller than the mockup: 24 is right at the sides and too much
  /// between stacked sections.
  static const block = 20.0;

  /// Vertical padding inside a list row.
  static const row = 11.0;
}

/// Corner radii. The document says "rounded"; these are the values drawn.
abstract final class NookRadius {
  /// Navigation tiles, thumbnails, avatar squares.
  static const sm = 12.0;

  /// Cards, text fields, dialogs.
  static const md = 16.0;

  /// Buttons. Measured off the mockup, which is a little less round than the
  /// cards around it.
  static const button = 14.0;

  /// Chips and the search bar.
  static const pill = 999.0;
}

/// Fixed sizes taken from the mockup.
abstract final class NookMetrics {
  /// The mockup's primary button is 113px tall in an 882px-wide frame that maps
  /// to 390pt, which is 52.6pt.
  static const buttonHeight = 52.0;

  /// The rounded-square back button in the app bar.
  static const appBarButton = 40.0;
}
