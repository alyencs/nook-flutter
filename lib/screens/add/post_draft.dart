import '../../ai/ai_extractor.dart';
import '../../ai/categories.dart';
import '../../ai/platform_from_url.dart';

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
        creator = result.creator,
        destination = result.destination,
        country = result.country,
        category = NookCategories.normalise(result.category),
        summary = result.summary,
        bestTime = result.bestTime,
        budgetNote = result.budgetNote,
        fromSample = result.isSample;

  /// The "Enter manually" path, taken when extraction fails or the user would
  /// rather type it themselves.
  PostDraft.manual({required String url, required this.title})
      : url = url,
        platform = NookPlatform.fromUrl(url),
        importMethod = 'link',
        creator = null,
        destination = null,
        country = null,
        category = NookCategories.fallback,
        summary = null,
        bestTime = null,
        budgetNote = null,
        fromSample = false;

  /// A note with no link and no extraction: the second tile on Add Post.
  PostDraft.note({required this.title, this.note})
      : url = null,
        platform = NookPlatform.other,
        importMethod = 'note',
        creator = null,
        destination = null,
        country = null,
        category = NookCategories.fallback,
        summary = null,
        bestTime = null,
        budgetNote = null,
        fromSample = false;

  final String? url;
  final String platform;
  final String importMethod;

  /// True when the values came from the sample extractor rather than Gemini, so
  /// the review screen can say so instead of implying a real extraction.
  final bool fromSample;

  String title;
  String? creator;
  String? destination;
  String? country;
  String? category;
  String? summary;
  String? bestTime;
  String? budgetNote;

  int? tripId;
  String? tripName;
  String? note;

  bool get isNote => importMethod == 'note';
}
