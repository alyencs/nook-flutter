import '../ai/itinerary_generator.dart';
import '../ai/post_place.dart';
import '../data/database.dart';

/// Turns the posts saved into a trip into the context a plan is built from.
///
/// The seam between the database and `lib/ai`: the generator takes value types
/// and knows nothing about Drift. Nothing is invented or summarised here —
/// every field is one the extractor already filled in.
abstract final class ItineraryContext {
  /// The request for [trip], built from [posts].
  static ItineraryRequest requestFor({
    required String tripName,
    required List<SavedPost> posts,
    required int days,
  }) {
    return ItineraryRequest(
      destination: destinationOf(posts) ?? tripName,
      days: days,
      tripName: tripName,
      sources: posts.map(sourceOf).toList(growable: false),
    );
  }

  static ItinerarySource sourceOf(SavedPost post) => ItinerarySource(
    title: post.title,
    caption: post.caption,
    creator: post.creator ?? post.creatorHandle,
    platform: post.platform,
    category: post.aiCategory,
    summary: post.aiSummary,
    destination: post.aiDestination,
    placeName: post.aiPlaceName,
    neighbourhood: post.aiNeighbourhood,
    city: post.aiCity,
    region: post.aiRegion,
    country: post.aiCountry,
    bestTime: post.aiBestTime,
    budgetNote: post.aiBudgetNote,
    note: post.personalNote,
    places: PostPlace.decode(post.aiPlaces),
    highlights: PostHighlights.decode(post.aiHighlights),
  );

  /// Where this set of posts is, as a single string: the commonest destination
  /// rather than the first, so the odd post out does not name the trip. Null
  /// when nothing was ever extracted.
  static String? destinationOf(List<SavedPost> posts) {
    final counts = <String, int>{};
    for (final post in posts) {
      final value = _best(post);
      if (value == null) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;

    final ranked = counts.entries.toList()
      // Count first, then alphabetically, so a tie is stable rather than
      // whichever order the rows came back in.
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return ranked.first.key;
  }

  /// A post's most useful location string: the city if one was extracted,
  /// otherwise the display destination, otherwise the country.
  static String? _best(SavedPost post) {
    for (final value in [post.aiCity, post.aiDestination, post.aiCountry]) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  /// How many of [posts] carry more than a title, which is what decides
  /// whether a plan can be built at all.
  static int usableCount(List<SavedPost> posts) =>
      posts.where((post) => sourceOf(post).hasDetail).length;
}
