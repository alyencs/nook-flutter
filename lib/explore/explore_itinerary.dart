import '../theme/trip_colors.dart';

/// An itinerary offered for browsing, before it belongs to anyone.
///
/// Deliberately not a Drift table. This is read-only reference content, and it
/// has no business in tables that carry deletion, restore and export: clearing
/// a profile must not be able to empty the catalogue, and a curated itinerary
/// is not something the owner of the device wrote. Saving one is what reaches
/// the database — see `save_explore_itinerary.dart`.
class ExploreItinerary {
  const ExploreItinerary({
    required this.id,
    required this.title,
    required this.destination,
    required this.country,
    required this.days,
    required this.summary,
    required this.bestTime,
    required this.budgetNote,
    required this.colour,
    required this.stops,
    this.coverImage,
  });

  /// A stable slug. It keys the list and spots an itinerary that has already
  /// been saved, so it must not change once it has shipped.
  final String id;

  final String title;

  /// The one-line display location, composed the same way a saved post's is:
  /// "Kyoto, Japan". City first, country last.
  final String destination;

  final String country;

  /// How long the itinerary runs. Stored rather than counted off [stops],
  /// because a day with nothing planned on it is still a day.
  final int days;

  final String summary;
  final String bestTime;
  final String budgetNote;

  /// The folder colour the saved trip takes, so an itinerary looks the same
  /// before and after it is saved.
  final TripColor colour;

  final List<ExploreStop> stops;

  /// Null falls through to the drawn placeholder, which is what every other
  /// card in the app shows when there is no photograph.
  final String? coverImage;

  int get stopCount => stops.length;

  String get durationLabel => '$days ${days == 1 ? 'day' : 'days'}';

  String get stopsLabel => '$stopCount ${stopCount == 1 ? 'stop' : 'stops'}';

  /// The day numbers that actually carry stops, in order. Read off the stops
  /// rather than counted to [days], so a gap cannot render an empty heading.
  List<int> get dayNumbers =>
      (stops.map((stop) => stop.day).toSet().toList()..sort());

  List<ExploreStop> stopsOnDay(int day) =>
      stops.where((stop) => stop.day == day).toList(growable: false);
}

/// One place on one day.
///
/// Every field maps onto a `saved_posts` column that already exists, which is
/// what lets an itinerary be saved without a schema change.
class ExploreStop {
  const ExploreStop({
    required this.day,
    required this.title,
    required this.placeName,
    required this.category,
    required this.summary,
    this.area,
    this.image,
    this.latitude,
    this.longitude,
    this.highlights = const [],
  });

  final int day;
  final String title;

  /// The venue or landmark itself, not the city containing it.
  final String placeName;

  /// One of `NookCategories.all`. Passed through `normalise` on save, so a
  /// value no screen can filter becomes "Other" rather than a dead category.
  final String category;

  final String summary;

  /// District, street or station. Null when the stop is the whole place.
  final String? area;

  final String? image;

  /// Only where the stop is specific enough to have a single point. A stop
  /// that names a region leaves both null, exactly as extraction would.
  final double? latitude;
  final double? longitude;

  final List<String> highlights;

  bool get hasCoordinates => latitude != null && longitude != null;
}
