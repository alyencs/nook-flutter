import '../../ai/ai_extractor.dart';
import '../../ai/categories.dart';
import '../../ai/platform_from_url.dart';
import '../../ai/source_metadata.dart';
import '../../ai/thumbnail_from_url.dart';

/// What the add flow carries from one screen to the next.
///
/// Nothing is written to the database until "Save Post" on the review screen,
/// so backing out of the flow leaves no half-saved rows behind.
class PostDraft {
  PostDraft.fromLink({required String url, required ExtractionResult result})
      : url = url,
        platform = NookPlatform.fromUrl(url),
        importMethod = 'link',
        title = result.title,
        caption = result.caption,
        creator = result.creator,
        creatorHandle = result.creatorHandle,
        destination = result.destination,
        placeName = result.placeName,
        address = result.address,
        neighbourhood = result.neighbourhood,
        city = result.city,
        region = result.region,
        country = result.country,
        sourceId = result.sourceId,
        mediaType = result.mediaType,
        category = NookCategories.normalise(result.category),
        summary = result.summary,
        bestTime = result.bestTime,
        budgetNote = result.budgetNote,
        latitude = result.latitude,
        longitude = result.longitude,
        thumbnailUrl = result.thumbnailUrl,
        fromSample = result.isSample;

  /// The "Enter manually" path, taken when extraction fails or the user would
  /// rather type it themselves.
  PostDraft.manual({required String url, required this.title})
      : url = url,
        platform = NookPlatform.fromUrl(url),
        importMethod = 'link',
        caption = null,
        creator = null,
        creatorHandle = null,
        destination = null,
        placeName = null,
        address = null,
        neighbourhood = null,
        city = null,
        region = null,
        country = null,
        sourceId = SourceIds.of(url, NookPlatform.fromUrl(url)),
        mediaType = SourceIds.mediaTypeFrom(url, NookPlatform.fromUrl(url)),
        category = NookCategories.fallback,
        summary = null,
        bestTime = null,
        budgetNote = null,
        latitude = null,
        longitude = null,
        thumbnailUrl = PostThumbnails.fromUrl(url),
        fromSample = false;

  /// A note with no link and no extraction: the second tile on Add Post.
  PostDraft.note({required this.title, this.note})
      : url = null,
        platform = NookPlatform.other,
        importMethod = 'note',
        caption = null,
        creator = null,
        creatorHandle = null,
        destination = null,
        placeName = null,
        address = null,
        neighbourhood = null,
        city = null,
        region = null,
        country = null,
        sourceId = null,
        mediaType = PostMediaType.unknown,
        category = NookCategories.fallback,
        summary = null,
        bestTime = null,
        budgetNote = null,
        latitude = null,
        longitude = null,
        thumbnailUrl = null,
        fromSample = false;

  final String? url;
  final String platform;
  final String importMethod;

  /// True when the values came from the sample extractor rather than Gemini, so
  /// the review screen can say so instead of implying a real extraction.
  final bool fromSample;

  String title;
  String? caption;
  String? creator;
  String? creatorHandle;
  String? destination;
  String? placeName;
  String? address;
  String? neighbourhood;
  String? city;
  String? region;
  String? country;
  final String? sourceId;
  final PostMediaType mediaType;
  String? category;
  String? summary;
  String? bestTime;
  String? budgetNote;
  double? latitude;
  double? longitude;
  String? thumbnailUrl;

  int? tripId;
  String? tripName;
  String? note;

  bool get isNote => importMethod == 'note';
}
