/// What one extraction call returns.
///
/// Every field is nullable on purpose. The proposal's second risk is that a
/// destination comes back too vague to use, or not at all, so "no value" is a
/// normal result rather than a failure — screens render an em dash for it.
class ExtractionResult {
  const ExtractionResult({
    required this.title,
    this.creator,
    this.destination,
    this.country,
    this.category,
    this.summary,
    this.bestTime,
    this.budgetNote,
    this.latitude,
    this.longitude,
    this.thumbnailUrl,
    this.isSample = false,
  });

  final String title;
  final String? creator;
  final String? destination;
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

  bool get hasCoordinates => latitude != null && longitude != null;

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
