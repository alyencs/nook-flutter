import 'dart:convert';

import 'daos/settings_dao.dart';
import 'database.dart';
import 'export_io.dart' if (dart.library.js_interop) 'export_web.dart';

/// "Export Data" on the Settings screen.
///
/// Everything Nook holds about you, as one JSON file: the profile, the trips,
/// every saved post with its extracted metadata and your notes, the search
/// history and the settings. It is written locally — on the web the browser
/// downloads it, on a device it is written to the app's documents directory.
/// Nothing is uploaded.
///
/// **"Everything" is now true.** It was not: this wrote the columns the table
/// had when it was first written and never grew with it, so thirteen post
/// columns added in schemas 3 to 7 — the caption, the handle, the source id and
/// media type, the whole specific-location chain, the named places and the
/// highlights, the creator's page and picture — were silently absent, along
/// with a trip's colour. An export is the thing a person reaches for when they
/// want their data out, and a subset described as everything is the kind of
/// claim that matters.
///
/// Two ways to settle that: narrow the sentence, or widen the export. The
/// export is widened, because the honest version of this feature is the
/// complete one. `format_version` is 2 to mark the change.
///
/// Soft-deleted rows are included, with their `deleted_at`, because a post
/// waiting in Recently Deleted is still the user's and still on the device.
abstract final class NookExport {
  /// `ai_places` and `ai_highlights` are JSON held in a text column. Exporting
  /// the raw string would hand someone an escaped blob inside a JSON file, so
  /// they go back to being a list before they are written.
  static Object? _decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  static Future<String> run(NookDatabase db) async {
    final users = await db.select(db.users).get();
    final trips = await db.select(db.trips).get();
    final posts = await db.select(db.savedPosts).get();
    final searches = await db.select(db.recentSearches).get();
    final settings = await SettingsDao(db).current();

    final data = {
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'Nook',
      'format_version': 2,
      'profile': users
          .map(
            (u) => {
              'name': u.name,
              'email': u.email,
              // The photo is a data URI and can be large; it is included so
              // the export is genuinely everything, not almost everything.
              'profile_picture': u.profilePicture,
            },
          )
          .toList(),
      'trips': trips
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'created_at': t.createdAt.toIso8601String(),
              'color_id': t.colorId,
              'deleted_at': t.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'saved_posts': posts
          .map(
            (p) => {
              'id': p.id,
              'title': p.title,
              'caption': p.caption,
              'creator': p.creator,
              'creator_handle': p.creatorHandle,
              'creator_url': p.creatorUrl,
              'creator_avatar_url': p.creatorAvatarUrl,
              'platform': p.platform,
              'source_id': p.sourceId,
              'media_type': p.mediaType,
              'original_url': p.originalUrl,
              'import_method': p.importMethod,
              'thumbnail_url': p.thumbnailUrl,
              'destination': p.aiDestination,
              'place_name': p.aiPlaceName,
              'address': p.aiAddress,
              'neighbourhood': p.aiNeighbourhood,
              'city': p.aiCity,
              'region': p.aiRegion,
              'country': p.aiCountry,
              'category': p.aiCategory,
              'summary': p.aiSummary,
              'best_time': p.aiBestTime,
              'budget_note': p.aiBudgetNote,
              // Stored as JSON strings, so they are decoded back into real
              // structure here rather than exported as quoted blobs.
              'places': _decodeList(p.aiPlaces),
              'highlights': _decodeList(p.aiHighlights),
              'latitude': p.aiLatitude,
              'longitude': p.aiLongitude,
              'trip_id': p.tripId,
              'personal_note': p.personalNote,
              'date_saved': p.dateSaved.toIso8601String(),
              'last_viewed_at': p.lastViewedAt?.toIso8601String(),
              'note_edited_at': p.noteEditedAt?.toIso8601String(),
              'deleted_at': p.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'recent_searches': searches
          .map(
            (s) => {
              'query': s.query,
              'searched_at': s.searchedAt.toIso8601String(),
            },
          )
          .toList(),
      'settings': settings,
    };

    final stamp = DateTime.now().toIso8601String().split('T').first;

    return saveExport(
      const JsonEncoder.withIndent('  ').convert(data),
      'nook-export-$stamp.json',
    );
  }
}
