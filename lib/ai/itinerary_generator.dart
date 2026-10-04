import 'itinerary.dart';
import 'post_place.dart';

/// One saved post, flattened into the facts an itinerary can be built from.
///
/// A value type rather than the Drift row on purpose: `lib/ai` knows nothing
/// about the database, the same way [AiExtractor] does not, so the generator
/// can be tested without one and the data layer can change shape without
/// reaching in here.
class ItinerarySource {
  const ItinerarySource({
    required this.title,
    this.caption,
    this.creator,
    this.platform,
    this.category,
    this.summary,
    this.destination,
    this.placeName,
    this.neighbourhood,
    this.city,
    this.region,
    this.country,
    this.bestTime,
    this.budgetNote,
    this.note,
    this.places = const [],
    this.highlights = const [],
  });

  final String title;
  final String? caption;
  final String? creator;
  final String? platform;
  final String? category;
  final String? summary;

  final String? destination;
  final String? placeName;
  final String? neighbourhood;
  final String? city;
  final String? region;
  final String? country;

  final String? bestTime;
  final String? budgetNote;

  /// What the traveller wrote on the post themselves, which outranks anything
  /// the platform said: it is the only part they chose the words for.
  final String? note;

  final List<PostPlace> places;
  final List<String> highlights;

  /// Whether this post carries anything an itinerary could use beyond a title.
  bool get hasDetail =>
      (caption != null && caption!.trim().isNotEmpty) ||
      (summary != null && summary!.trim().isNotEmpty) ||
      (note != null && note!.trim().isNotEmpty) ||
      placeName != null ||
      places.isNotEmpty ||
      highlights.isNotEmpty;

  /// This post, written out for the model to read.
  String toPromptBlock(int index) {
    final buffer = StringBuffer()..writeln('--- SAVED POST $index ---');
    void line(String label, String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty) return;
      buffer.writeln('$label: $text');
    }

    line('TITLE', title);
    line('PLATFORM', platform);
    line('CREATOR', creator);
    line('CATEGORY', category);
    line('DESTINATION', destination);
    line('PLACE', placeName);
    line('AREA', neighbourhood);
    line('CITY', city);
    line('REGION', region);
    line('COUNTRY', country);
    line('BEST_TIME', bestTime);
    line('BUDGET', budgetNote);
    line('SUMMARY', summary);
    line('POST_TEXT', caption);
    line("TRAVELLER'S OWN NOTE", note);

    if (places.isNotEmpty) {
      buffer.writeln('PLACES NAMED IN THIS POST:');
      for (final place in places) {
        final parts = <String>[
          place.name,
          ?place.kind,
          ?place.area,
          ?place.note,
        ];
        buffer.writeln('  - ${parts.join(' · ')}');
      }
    }

    if (highlights.isNotEmpty) {
      buffer.writeln('TIPS FROM THIS POST:');
      for (final line in highlights) {
        buffer.writeln('  - $line');
      }
    }

    return buffer.toString();
  }
}

/// What to build, and what to build it from.
class ItineraryRequest {
  const ItineraryRequest({
    required this.destination,
    required this.days,
    required this.sources,
    this.tripName,
  });

  /// Where the trip is. Taken from the saved posts rather than typed, so it is
  /// the same string the posts and the map already agree on.
  final String destination;

  /// How many days the traveller asked for. The generator is held to it.
  final int days;

  final List<ItinerarySource> sources;

  /// The trip's own name, when it differs from the destination.
  final String? tripName;

  /// The posts that carry more than a title, which are the ones worth sending.
  List<ItinerarySource> get usableSources =>
      sources.where((source) => source.hasDetail).toList(growable: false);

  bool get hasSources => sources.isNotEmpty;

  /// Whether there is enough here to build a day-by-day plan from rather than
  /// inventing one around a place name.
  bool get hasEnoughDetail => usableSources.isNotEmpty;

  String toPromptBlock() {
    final buffer = StringBuffer()
      ..writeln('DESTINATION: $destination')
      ..writeln('DAYS REQUESTED: $days');
    if (tripName != null && tripName!.trim() != destination.trim()) {
      buffer.writeln('TRIP NAME: ${tripName!.trim()}');
    }
    buffer.writeln('SAVED POSTS: ${sources.length}');
    buffer.writeln();
    for (var i = 0; i < sources.length; i++) {
      buffer.writeln(sources[i].toPromptBlock(i + 1));
    }
    return buffer.toString();
  }
}

/// Where generation has got to.
///
/// Three phases, and the screen chooses the words — the same arrangement
/// [ExtractionPhase] uses, and for the same reason: a vendor name, a model id
/// or an HTTP status is never the traveller's problem.
enum ItineraryPhase {
  /// Gathering the saved posts for the trip.
  readingSaves,

  /// The model call, including any retry.
  planning,

  /// Turning the reply into days.
  finishing,
}

typedef ItineraryStage = void Function(ItineraryPhase phase);

/// One interface, two implementations, chosen at startup by whether a key is
/// present — exactly as extraction is.
abstract interface class ItineraryGenerator {
  Future<GeneratedItinerary> generate(
    ItineraryRequest request, {
    ItineraryStage? onStage,
  });

  /// Whether this generator is the real thing.
  bool get isLive;
}

/// Thrown when an itinerary cannot be produced in a way the traveller should
/// see: nothing saved to build from, a rejected key, an unusable reply.
class ItineraryException implements Exception {
  const ItineraryException(this.message);

  final String message;

  @override
  String toString() => message;
}
