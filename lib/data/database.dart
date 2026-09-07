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

  @override
  int get schemaVersion => 1;

  /// SQLite does not enforce foreign keys unless asked to. Without this, a
  /// post could keep pointing at a deleted trip, which is exactly the
  /// relationship the storage decision was made for.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated) await seedDatabase(this);
        },
      );

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
