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

  /// Bumped to 2 when `app_settings` and the coordinate columns were added.
  ///
  /// They were added at version 1 without bumping this, which is the bug behind
  /// "no such table: app_settings": drift creates the whole schema only for a
  /// database it creates itself, so every database that already existed stayed
  /// on the old shape and no migration ever ran.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDatabase(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await _upgradeToV2(m);
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
  /// account" on the Account screen.
  Future<void> clearAll() async {
    await batch((b) {
      b.deleteAll(savedPosts);
      b.deleteAll(trips);
      b.deleteAll(users);
      b.deleteAll(recentSearches);
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
