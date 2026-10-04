import 'package:drift/drift.dart' show Value;

import '../ai/categories.dart';
import '../ai/platform_from_url.dart';
import '../ai/post_place.dart';
import '../app_scope.dart';
import '../data/database.dart';
import 'explore_itinerary.dart';

/// Writes a browsed itinerary into the user's own trips.
///
/// Nothing new is stored to make this work: the itinerary becomes one row in
/// `trips` and one row per stop in `saved_posts`, through the same two DAO
/// calls the add flow already uses. Because every screen reads those tables
/// through Drift streams, the new trip reaches Trips, Home's recent saves and
/// search the moment the last insert lands — there is nothing to refresh.
///
/// Returns the new trip's id, or null when there is no profile yet.
Future<int?> saveExploreItinerary(
  AppScope scope,
  ExploreItinerary itinerary,
) async {
  final user = await scope.users.currentUser();
  if (user == null) return null;

  final tripId = await scope.trips.createTrip(
    itinerary.title,
    user.id,
    colour: itinerary.colour,
  );

  // One timestamp for the whole itinerary, so its stops arrive together in
  // Recent Saves rather than in an order nobody chose.
  final savedAt = DateTime.now();

  for (final stop in itinerary.stops) {
    await scope.posts.insertPost(
      SavedPostsCompanion.insert(
        title: stop.title,
        // There is no post behind a curated stop, so there is no URL and no
        // platform to read off one. `note` is the other of the two import
        // methods, and it is the honest one here.
        platform: NookPlatform.other,
        importMethod: 'note',
        tripId: Value(tripId),
        dateSaved: savedAt,
        // A stop without its own photograph falls back to the itinerary's
        // cover, which is better than an empty card in the trip.
        thumbnailUrl: Value(stop.image ?? itinerary.coverImage),
        aiDestination: Value(itinerary.destination),
        aiCountry: Value(itinerary.country),
        aiCity: Value(_cityOf(itinerary.destination)),
        aiCategory: Value(NookCategories.normalise(stop.category)),
        aiSummary: Value(stop.summary),
        aiPlaceName: Value(stop.placeName),
        aiNeighbourhood: Value(stop.area),
        aiBestTime: Value(itinerary.bestTime),
        aiBudgetNote: Value(itinerary.budgetNote),
        aiLatitude: Value(stop.latitude),
        aiLongitude: Value(stop.longitude),
        aiHighlights: Value(PostHighlights.encode(stop.highlights)),
      ),
    );
  }

  return tripId;
}

/// Whether a trip of this name is already in the library.
///
/// Matched on the name rather than on an id, because a saved itinerary is an
/// ordinary trip from that point on: it can be renamed, added to and emptied,
/// and nothing should pretend it is still a copy of the catalogue entry.
Future<bool> exploreItinerarySaved(
  AppScope scope,
  ExploreItinerary itinerary,
) async {
  final trips = await scope.trips.allTrips();
  return trips.any((trip) => trip.name == itinerary.title);
}

/// "Kyoto, Japan" gives Kyoto. The city feeds search, which matches on it.
String? _cityOf(String destination) {
  final city = destination.split(',').first.trim();
  return city.isEmpty ? null : city;
}
