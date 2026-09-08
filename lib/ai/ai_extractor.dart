import 'source_metadata.dart';

/// What one extraction call returns.
///
/// Every field is nullable on purpose. The proposal's second risk is that a
/// destination comes back too vague to use, or not at all, so "no value" is a
/// normal result rather than a failure — screens render an em dash for it.
class ExtractionResult {
  const ExtractionResult({
    required this.title,
    this.caption,
    this.creator,
    this.creatorHandle,
    this.destination,
    this.placeName,
    this.address,
    this.neighbourhood,
    this.city,
    this.region,
    this.country,
    this.category,
    this.summary,
    this.bestTime,
    this.budgetNote,
    this.latitude,
    this.longitude,
    this.thumbnailUrl,
    this.sourceId,
    this.mediaType = PostMediaType.unknown,
    this.isSample = false,
  });

  /// The real, human title of the post. Never the platform's id for it — see
  /// [sourceId], which is where that belongs.
  final String title;

  /// The post's own words: a YouTube description, a TikTok or Instagram
  /// caption. Kept whole, because it is the thing a person recognises the post
  /// by and the thing search is most likely to match.
  final String? caption;

  final String? creator;
  final String? creatorHandle;

  /// The one-line display location, composed from the parts below.
  final String? destination;

  // --- Location, from most specific to least. Extraction fills in as far down
  // this list as the source actually supports, and stops: "Japan" alone is a
  // true answer for a link that says nothing more, and a cafe in Nakazakicho is
  // the answer for one that does.
  final String? placeName;
  final String? address;
  final String? neighbourhood;
  final String? city;
  final String? region;
  final String? country;

  final String? category;
  final String? summary;
  final String? bestTime;
  final String? budgetNote;

  /// Where to drop the map pin. Null when the destination is missing or too
  /// broad to place on a map.
  final double? latitude;
  final double? longitude;

  /// A preview image for the post, when one can be worked out from the link.
  final String? thumbnailUrl;

  /// The platform's own id — a YouTube video id, an Instagram shortcode. Held
  /// as metadata so that nothing is ever tempted to show it as a title.
  final String? sourceId;

  /// Whether the post is a video, a photo, or a gallery. Not assumed.
  final PostMediaType mediaType;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Whether the location is specific enough to be worth a map pin.
  ///
  /// A country name is a true answer but not a place: dropping a marker on the
  /// middle of Japan claims a precision the source never had.
  bool get hasPreciseLocation =>
      placeName != null || address != null || neighbourhood != null ||
      city != null;

  /// True when this came from [SampleExtractor], so the UI can say so out loud
  /// instead of passing invented data off as a real extraction.
  final bool isSample;
}

/// Called as extraction moves through its steps, so the screen can say what is
/// happening instead of showing an unexplained spinner.
typedef ExtractionStage = void Function(String message);

/// One interface, two implementations, chosen at startup by whether a Gemini
/// key is present. This is the proposal's own "one interface, two
/// implementations" fallback pattern, applied to the key problem.
abstract interface class AiExtractor {
  Future<ExtractionResult> extract(String url, {ExtractionStage? onStage});

  /// Whether this extractor is the real thing.
  bool get isLive;
}

/// Thrown when extraction fails in a way the user should see: no network, a
/// rejected key, an unparseable reply.
class ExtractionException implements Exception {
  const ExtractionException(this.message);

  final String message;

  @override
  String toString() => message;
}
