/// The one category vocabulary, used by the extraction prompt, the chips on the
/// Destination & Category screen and the suggestion chips on Search.
///
/// The mockup drew two different lists (six on Search, seven on Add); this is
/// the union of both, so nothing drawn is lost. See decision 6 in
/// docs/07-build-plan.md.
abstract final class NookCategories {
  static const all = <String>[
    'Food',
    'Travel',
    'Itinerary',
    'Accommodation',
    'Adventure',
    'Scenery',
    'Nightlife',
    'Other',
  ];

  /// What an unrecognised or missing category becomes.
  static const fallback = 'Other';

  /// Maps whatever came back from the model onto the vocabulary above.
  static String normalise(String? raw) {
    if (raw == null) return fallback;
    final match = raw.trim().toLowerCase();
    for (final category in all) {
      if (category.toLowerCase() == match) return category;
    }
    return fallback;
  }
}
