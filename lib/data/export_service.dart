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
abstract final class NookExport {
  static Future<String> run(NookDatabase db) async {
    final users = await db.select(db.users).get();
    final trips = await db.select(db.trips).get();
    final posts = await db.select(db.savedPosts).get();
    final searches = await db.select(db.recentSearches).get();
    final settings = await SettingsDao(db).current();

    final data = {
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'Nook',
      'format_version': 1,
      'profile': users
          .map((u) => {
                'name': u.name,
                'email': u.email,
                // The photo is a data URI and can be large; it is included so
                // the export is genuinely everything, not almost everything.
                'profile_picture': u.profilePicture,
              })
          .toList(),
      'trips': trips
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'created_at': t.createdAt.toIso8601String(),
              })
          .toList(),
      'saved_posts': posts
          .map((p) => {
                'id': p.id,
                'title': p.title,
                'creator': p.creator,
                'platform': p.platform,
                'original_url': p.originalUrl,
                'import_method': p.importMethod,
                'thumbnail_url': p.thumbnailUrl,
                'destination': p.aiDestination,
                'country': p.aiCountry,
                'category': p.aiCategory,
                'summary': p.aiSummary,
                'best_time': p.aiBestTime,
                'budget_note': p.aiBudgetNote,
                'latitude': p.aiLatitude,
                'longitude': p.aiLongitude,
                'trip_id': p.tripId,
                'personal_note': p.personalNote,
                'date_saved': p.dateSaved.toIso8601String(),
                'last_viewed_at': p.lastViewedAt?.toIso8601String(),
                'note_edited_at': p.noteEditedAt?.toIso8601String(),
              })
          .toList(),
      'recent_searches': searches
          .map((s) => {
                'query': s.query,
                'searched_at': s.searchedAt.toIso8601String(),
              })
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
