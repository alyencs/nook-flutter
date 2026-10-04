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

  /// 2 added `app_settings` and the coordinate columns; 3 the columns that keep
  /// a full extraction; 4 places and highlights, and relaxed `users.email`; 5
  /// `deleted_at` on posts and trips, which Recently Deleted is built on; 6 a
  /// trip's folder colour; 7 the creator's page URL and profile picture.
  ///
  /// Some of these shipped at version 1 without bumping this, which is the bug
  /// behind "no such table: app_settings": drift creates the whole schema only
  /// for a database it creates itself, so existing databases never migrated.
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
  /// "Version 1" describes two shapes in the wild — with and without these
  /// columns — because the version was not bumped when they were added. Both
  /// arrive here, so each piece is added only if it is missing.
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
  /// Existing posts gain nulls, which every screen renders as an em dash.
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
  /// required. SQLite cannot relax NOT NULL in place, so `users` is rebuilt
  /// through drift's `TableMigration`, copying every existing row across.
  Future<void> _upgradeToV4(Migrator m) async {
    for (final entry in <String, GeneratedColumn<String>>{
      'ai_places': savedPosts.aiPlaces,
      'ai_highlights': savedPosts.aiHighlights,
    }.entries) {
      if (!await _hasColumn('saved_posts', entry.key)) {
        await m.addColumn(savedPosts, entry.value);
      }
    }
    // Experimental, but the documented way to rebuild a table — and rebuilding
    // is the only way SQLite will relax a NOT NULL constraint.
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(users));
  }

  /// Version 5: Recently Deleted. Two nullable timestamps, so existing rows
  /// arrive with null, which is exactly what "not deleted" means.
  Future<void> _upgradeToV5(Migrator m) async {
    if (!await _hasColumn('saved_posts', 'deleted_at')) {
      await m.addColumn(savedPosts, savedPosts.deletedAt);
    }
    if (!await _hasColumn('trips', 'deleted_at')) {
      await m.addColumn(trips, trips.deletedAt);
    }
  }

  /// Version 6: the trip folder colour. Nullable, so existing trips arrive with
  /// "nobody chose" and [TripColor.forId] spreads them across the palette.
  Future<void> _upgradeToV6(Migrator m) async {
    if (!await _hasColumn('trips', 'color_id')) {
      await m.addColumn(trips, trips.colorId);
    }
  }

  /// Version 7: who made the post, beyond a name. `creator_url` comes from
  /// oEmbed on all four platforms; `creator_avatar_url` from YouTube alone.
  /// Both nullable, and a post without one draws the creator's initial.
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

  /// Inserts the demo library if the database came up empty.
  ///
  /// The seed normally runs from [migration]'s `beforeOpen` on creation; this
  /// covers a database that exists but was emptied. Without it a fresh browser
  /// opening the live link lands on an empty app. All of it is fictional.
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
  /// `app_settings` is included deliberately: the dialog says this erases
  /// everything on the device, and a settings row is the user's own choice, so
  /// the next profile should not inherit it. Anything absent falls back to
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
    // deployed build white-screens with no error.
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
