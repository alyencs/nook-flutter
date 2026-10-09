import 'location_scope.dart';
import 'post_place.dart';
import 'source_metadata.dart';

/// What one extraction call returns.
///
/// Every field is nullable on purpose: a destination that comes back vague, or
/// not at all, is a normal result rather than a failure, and screens render an
/// em dash for it.
class ExtractionResult {
  const ExtractionResult({
    required this.title,
    this.caption,
    this.creator,
    this.creatorHandle,
    this.creatorUrl,
    this.creatorAvatarUrl,
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
    this.places = const [],
    this.highlights = const [],
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

  /// The creator's page on the platform, when oEmbed gave one.
  final String? creatorUrl;

  /// The creator's profile picture, when the platform publishes one.
  ///
  /// Read from the source, never from the model, which would invent a plausible
  /// URL to an image that does not exist. In practice YouTube only — see
  /// [SourceMetadata.creatorAvatarUrl].
  final String? creatorAvatarUrl;

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

  /// Every specific venue the source named, in the order it named them. This is
  /// what makes "5 Cafes in Kyoto" five cafes rather than one city.
  final List<PostPlace> places;

  /// Activities, recommendations and tips, one line each.
  final List<String> highlights;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Whether the location is a particular spot rather than a whole city,
  /// region or country. Decides how closely the map is framed, not whether
  /// there is one: every located post gets a map.
  bool get hasPreciseLocation =>
      placeName != null ||
      address != null ||
      neighbourhood != null ||
      city != null;

  /// How specific the location is, which is what the map zooms to.
  LocationScope get locationScope => LocationScope.of(
    placeName: placeName,
    address: address,
    neighbourhood: neighbourhood,
    city: city,
    region: region,
    country: country,
    destination: destination,
  );

  /// True when this came from [SampleExtractor], so the UI can say so out loud
  /// instead of passing invented data off as a real extraction.
  final bool isSample;
}

/// Where extraction has got to.
///
/// A phase, not a sentence: the extractor says which of three things is
/// happening and the screen chooses the words, so a model id or a retry
/// schedule cannot reach the UI even by accident.
enum ExtractionPhase {
  /// Fetching the post itself from its platform.
  readingPost,

  /// The model call, including any retry or move to another model. From the
  /// outside these are one wait.
  analysing,

  /// Turning the reply into something Nook can save.
  finishing,
}

/// Called as extraction moves through its steps, so the screen can show
/// progress instead of an unexplained spinner.
typedef ExtractionStage = void Function(ExtractionPhase phase);

/// One interface, two implementations, chosen at startup by whether an API key
/// is present.
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
