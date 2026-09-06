/// The design system's spacing rule, and the radius scale the mockup draws.
abstract final class NookSpacing {
  /// Between related items.
  static const tight = 8.0;

  /// Between sections.
  static const section = 16.0;

  /// Screen edge padding.
  static const screenEdge = 24.0;
}

/// Corner radii. The document says "rounded"; these are the values drawn.
abstract final class NookRadius {
  /// Navigation tiles, thumbnails, avatar squares.
  static const sm = 12.0;

  /// Cards, buttons, text fields, dialogs.
  static const md = 16.0;

  /// Chips and the search bar.
  static const pill = 999.0;
}
