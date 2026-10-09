/// How specific a saved post's location is.
///
/// Derived from the location fields an extraction already filled in, so it
/// costs no storage and a post saved before this existed reads the same way as
/// one saved after it.
///
/// The scope decides how far the map is zoomed out. Every located post gets a
/// map; what changes is the frame. A cafe at country zoom is a dot in an ocean,
/// and a country at street zoom is a pin in a field — the honest answer is to
/// show the area the post is actually about.
enum LocationScope {
  /// A named venue or a street address.
  venue(zoom: 15.5),

  /// A district or neighbourhood.
  district(zoom: 13.5),

  /// A town or city.
  city(zoom: 11, featureType: 'settlement'),

  /// A prefecture, state, province, or a named area larger than a city.
  region(zoom: 6.5, featureType: 'state'),

  /// A whole country.
  country(zoom: 4.5, featureType: 'country'),

  /// Somewhere named, of a kind nothing identified — "Southeast Asia", "the
  /// Alps". The widest frame, and a free-form lookup, because there is nothing
  /// to narrow it to.
  area(zoom: 4.5),

  /// Nothing geographic was extracted at all.
  none(zoom: 2);

  const LocationScope({required this.zoom, this.featureType});

  /// The `flutter_map` zoom level that frames this kind of place.
  final double zoom;

  /// Narrows a geocoder lookup to the kind of thing being asked for, so a
  /// country query cannot match a side street that happens to share its name.
  /// Null leaves the search free-form, which is what a venue needs.
  final String? featureType;

  bool get isMappable => this != LocationScope.none;

  /// Reads the scope off the location fields, most specific first.
  ///
  /// [destination] is the one-line display string and is the last resort: a
  /// post about "Southeast Asia" fills none of the structured fields, and is
  /// still somewhere that can be shown.
  static LocationScope of({
    String? placeName,
    String? address,
    String? neighbourhood,
    String? city,
    String? region,
    String? country,
    String? destination,
  }) {
    bool has(String? value) => value != null && value.trim().isNotEmpty;

    if (has(placeName) || has(address)) return LocationScope.venue;
    if (has(neighbourhood)) return LocationScope.district;
    if (has(city)) return LocationScope.city;
    if (has(region)) return LocationScope.region;
    if (has(country)) return LocationScope.country;
    if (has(destination)) return LocationScope.area;
    return LocationScope.none;
  }
}
