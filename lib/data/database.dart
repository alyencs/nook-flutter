import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Users, Trips, SavedPosts, RecentSearches, AppSettings])
class NookDatabase extends _$NookDatabase {
  NookDatabase() : super(_open());

  /// For tests: an in-memory database with no seed data.
  NookDatabase.forTesting(super.executor);

  /// 2 added `app_settings` and the coordinate columns; 3 added the columns
  /// that keep a full extraction — caption, creator handle, source id, media
  /// type and the specific location parts; 4 added the places and highlights a
  /// post mentions, and relaxed `users.email` now that nothing collects it; 5
  /// added `deleted_at` to posts and trips, which is what Recently Deleted is
  /// built on; 6 added a trip's folder colour; 7 added the creator's page URL
  /// and profile picture.
  ///
  /// They were added at version 1 without bumping this, which is the bug behind
  /// "no such table: app_settings": drift creates the whole schema only for a
  /// database it creates itself, so every database that already existed stayed
  /// on the old shape and no migration ever ran.
  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedDatabase(this);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await _upgradeToV2(m);
      if (from < 3) await _upgradeToV3(m);
      if (from < 4) await _upgradeToV4(m);
      if (from < 5) await _upgradeToV5(m);
      if (from < 6) await _upgradeToV6(m);
      if (from < 7) await _upgradeToV7(m);
    },
    beforeOpen: (details) async {
      // SQLite does not enforce foreign keys unless asked to. Without
      // this, a post could keep pointing at a deleted trip, which is
      // exactly the relationship the storage decision was made for.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Adds what version 2 introduced, skipping anything already there.
  ///
  /// The checks are not defensive programming for its own sake. Because the
  /// version was not bumped when these were added, "version 1" describes two
  /// different shapes in the wild: databases created before the additions,
  /// which lack them, and databases created after, which have them and are
  /// still stamped 1. Both arrive here, so each piece is added only if it is
  /// actually missing.
  Future<void> _upgradeToV2(Migrator m) async {
    if (!await _hasTable('app_settings')) {
      await m.createTable(appSettings);
    }
    if (!await _hasColumn('saved_posts', 'ai_latitude')) {
      await m.addColumn(savedPosts, savedPosts.aiLatitude);
    }
    if (!await _hasColumn('saved_posts', 'ai_longitude')) {
      await m.addColumn(savedPosts, savedPosts.aiLongitude);
    }
  }

  /// Version 3: the columns that let a full extraction survive being saved.
  ///
  /// Before this, everything the model found beyond a destination, a country
  /// and a category was thrown away at the point of writing the row. Existing
  /// posts keep their values and gain nulls in the new columns, which every
  /// screen already renders as an em dash.
  Future<void> _upgradeToV3(Migrator m) async {
    final columns = <String, GeneratedColumn<String>>{
      'caption': savedPosts.caption,
      'creator_handle': savedPosts.creatorHandle,
      'source_id': savedPosts.sourceId,
      'media_type': savedPosts.mediaType,
      'ai_place_name': savedPosts.aiPlaceName,
      'ai_address': savedPosts.aiAddress,
      'ai_neighbourhood': savedPosts.aiNeighbourhood,
      'ai_city': savedPosts.aiCity,
      'ai_region': savedPosts.aiRegion,
    };
    for (final entry in columns.entries) {
      if (!await _hasColumn('saved_posts', entry.key)) {
        await m.addColumn(savedPosts, entry.value);
      }
    }
  }

  /// Version 4: places and highlights, and an email column that is no longer
  /// required.
  ///
  /// SQLite cannot relax a NOT NULL constraint in place, so `users` is rebuilt
  /// through drift's `TableMigration`, which copies every existing row across.
  /// Profiles created before this keep the address they gave; nothing reads it
  /// any more, and onboarding no longer asks.
  Future<void> _upgradeToV4(Migrator m) async {
    for (final entry in <String, GeneratedColumn<String>>{
      'ai_places': savedPosts.aiPlaces,
      'ai_highlights': savedPosts.aiHighlights,
    }.entries) {
      if (!await _hasColumn('saved_posts', entry.key)) {
        await m.addColumn(savedPosts, entry.value);
      }
    }
    // Drift marks TableMigration experimental, but it is the documented way to
    // rebuild a table, and rebuilding is the only way SQLite will relax a NOT
    // NULL constraint. It copies every existing row across.
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(users));
  }

  /// Version 5: Recently Deleted.
  ///
  /// Two nullable timestamps, so every existing post and trip arrives with a
  /// null — which is exactly what "not deleted" means — and nothing has to be
  /// backfilled.
  Future<void> _upgradeToV5(Migrator m) async {
    if (!await _hasColumn('saved_posts', 'deleted_at')) {
      await m.addColumn(savedPosts, savedPosts.deletedAt);
    }
    if (!await _hasColumn('trips', 'deleted_at')) {
      await m.addColumn(trips, trips.deletedAt);
    }
  }

  /// Version 6: the trip folder colour.
  ///
  /// Nullable, so every existing trip arrives with "nobody chose" rather than
  /// needing a backfill — and [TripColor.forId] spreads those across the five
  /// so an old library is not a wall of one colour.
  Future<void> _upgradeToV6(Migrator m) async {
    if (!await _hasColumn('trips', 'color_id')) {
      await m.addColumn(trips, trips.colorId);
    }
  }

  /// Version 7: who made the post, beyond a name.
  ///
  /// `creator_url` is available on all four platforms through oEmbed's
  /// `author_url`; `creator_avatar_url` is available on YouTube alone, and only
  /// with a Data API key. Both are nullable and stay null for every post saved
  /// before this, which every screen already renders as the creator's initial.
  Future<void> _upgradeToV7(Migrator m) async {
    for (final entry in <String, GeneratedColumn<String>>{
      'creator_url': savedPosts.creatorUrl,
      'creator_avatar_url': savedPosts.creatorAvatarUrl,
    }.entries) {
      if (!await _hasColumn('saved_posts', entry.key)) {
        await m.addColumn(savedPosts, entry.value);
      }
    }
  }

  Future<bool> _hasTable(String name) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((row) => row.read<String>('name') == column);
  }

  /// Inserts the demo library if the database somehow came up empty.
  ///
  /// Normally the seed runs from [migration]'s `beforeOpen` on creation. This
  /// is the belt-and-braces path for a database that exists but was emptied.
  ///
  /// Every mockup screen is drawn populated, so a fresh browser opening the
  /// live link would otherwise land on an empty app. All of it is fictional —
  /// no real names, links or personal data ship in this repository.
  Future<void> seedIfEmpty() async {
    final existing = await select(users).get();
    if (existing.isNotEmpty) return;
    await seedDatabase(this);
  }

  /// Wipes everything and re-seeds. Behind "Reset demo data" in Settings.
  Future<void> resetToSeed() async {
    await clearAll();
    await seedDatabase(this);
  }

  /// Wipes everything, leaving the app at onboarding. Behind "Delete my
  /// profile" on the Account screen.
  ///
  /// `app_settings` is in this list, and was not always. The dialog says "this
  /// erases everything on this device", and four of the five tables went —
  /// which made the sentence not quite true and left the next profile created
  /// on the device inheriting a stranger's toggles. Two ways to fix that: soften
  /// the dialog, or make the wipe match it.
  ///
  /// The wipe matches it. A settings row is the user's choice about their own
  /// library, so it belongs to the profile being deleted; and a device handed on
  /// or reset should come back at defaults rather than remembering preferences
  /// nobody can see any more. Anything absent falls back to
  /// [NookSettings.defaults], so emptying the table is the reset.
  Future<void> clearAll() async {
    await batch((b) {
      b.deleteAll(savedPosts);
      b.deleteAll(trips);
      b.deleteAll(users);
      b.deleteAll(recentSearches);
      b.deleteAll(appSettings);
    });
  }
}

QueryExecutor _open() {
  return driftDatabase(
    name: 'nook',
    // Both files live in web/ and are copied into the build. Without them the
    // deployed build white-screens with no error, which is why this landed in
    // phase 0 rather than late.
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
