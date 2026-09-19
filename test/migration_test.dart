import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/daos/settings_dao.dart';
import 'package:nook/data/database.dart';

/// The schema as it shipped at version 1: no `app_settings`, and no
/// coordinates on `saved_posts`.
const _v1Schema = [
  '''CREATE TABLE users (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       name TEXT NOT NULL,
       email TEXT NOT NULL,
       profile_picture TEXT NULL)''',
  '''CREATE TABLE trips (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       name TEXT NOT NULL,
       user_id INTEGER NOT NULL REFERENCES users(id),
       created_at INTEGER NOT NULL)''',
  '''CREATE TABLE saved_posts (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       title TEXT NOT NULL,
       creator TEXT NULL,
       platform TEXT NOT NULL,
       original_url TEXT NULL,
       import_method TEXT NOT NULL,
       thumbnail_url TEXT NULL,
       ai_destination TEXT NULL,
       ai_category TEXT NULL,
       ai_summary TEXT NULL,
       ai_country TEXT NULL,
       ai_best_time TEXT NULL,
       ai_budget_note TEXT NULL,
       trip_id INTEGER NULL REFERENCES trips(id) ON DELETE SET NULL,
       personal_note TEXT NULL,
       date_saved INTEGER NOT NULL,
       last_viewed_at INTEGER NULL,
       note_edited_at INTEGER NULL)''',
  '''CREATE TABLE recent_searches (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       query TEXT NOT NULL,
       searched_at INTEGER NOT NULL)''',
];

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nook_migration');
    file = File('${dir.path}/nook.sqlite');
  });

  tearDown(() async => dir.delete(recursive: true));

  /// Writes a database in the shape given, stamped with [userVersion].
  ///
  /// Built with raw sqlite3 rather than drift, so it is genuinely a database
  /// drift has never seen — which is the situation being tested.
  void writeOldDatabase(List<String> schema, {required int userVersion}) {
    final db = raw.sqlite3.open(file.path);
    for (final statement in schema) {
      db.execute(statement);
    }
    db.execute(
      "INSERT INTO users (name, email) VALUES ('Ali Sampang', 'ali@example.com')",
    );
    db.execute('PRAGMA user_version = $userVersion');
    db.dispose();
  }

  test('a version 1 database gains app_settings and the coordinates', () async {
    // This is the database that produced
    // "no such table: app_settings" when Export Data ran.
    writeOldDatabase(_v1Schema, userVersion: 1);

    final db = NookDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    // Reading it is what runs the migration.
    final settings = await SettingsDao(db).current();
    expect(settings, NookSettings.defaults);

    await SettingsDao(db).set(NookSettings.saveConfirmation, true);
    expect(
      await SettingsDao(db).isEnabled(NookSettings.saveConfirmation),
      isTrue,
    );

    // The coordinate columns arrived too, and the existing row survived.
    final posts = await db.select(db.savedPosts).get();
    expect(posts, isEmpty);
    final users = await db.select(db.users).get();
    expect(users.single.name, 'Ali Sampang');
  });

  test('a version 1 database that already has the additions is left alone',
      () async {
    // Databases created while the schema had grown but the version had not
    // are stamped 1 and already complete. The migration must not fail on them.
    writeOldDatabase([
      ..._v1Schema.map((s) => s.replaceFirst(
            'note_edited_at INTEGER NULL)',
            'note_edited_at INTEGER NULL, '
                'ai_latitude REAL NULL, ai_longitude REAL NULL)',
          )),
      '''CREATE TABLE app_settings (
           name TEXT NOT NULL,
           enabled INTEGER NOT NULL,
           PRIMARY KEY (name))''',
    ], userVersion: 1);

    final db = NookDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    final settings = await SettingsDao(db).current();
    expect(settings, NookSettings.defaults);
  });

  test('a database created from scratch has everything and is seeded',
      () async {
    final db = NookDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    expect(await SettingsDao(db).current(), NookSettings.defaults);
    expect(await db.select(db.savedPosts).get(), isNotEmpty);
  });

  test('a version 2 database gains the columns that keep a full extraction',
      () async {
    // Everything version 2 had, and nothing version 3 added.
    writeOldDatabase([
      ..._v1Schema.map((statement) => statement.replaceFirst(
            'note_edited_at INTEGER NULL)',
            'note_edited_at INTEGER NULL, '
                'ai_latitude REAL NULL, ai_longitude REAL NULL)',
          )),
      '''CREATE TABLE app_settings (
           name TEXT NOT NULL,
           enabled INTEGER NOT NULL,
           PRIMARY KEY (name))''',
    ], userVersion: 2);

    // A post saved before any of this existed.
    final old = raw.sqlite3.open(file.path);
    old.execute(
      "INSERT INTO saved_posts (title, platform, import_method, ai_country, "
      "date_saved) VALUES ('An older post', 'youtube', 'link', 'Japan', 0)",
    );
    old.dispose();

    final db = NookDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    // Reading through drift is what runs the migration.
    final posts = await db.select(db.savedPosts).get();
    final older = posts.firstWhere((row) => row.title == 'An older post');

    // The row survived, keeping what it had...
    expect(older.aiCountry, 'Japan');
    // ...and gained the new columns as nulls, which every screen already draws
    // as an em dash.
    expect(older.caption, isNull);
    expect(older.creatorHandle, isNull);
    expect(older.sourceId, isNull);
    expect(older.mediaType, isNull);
    expect(older.aiPlaceName, isNull);
    expect(older.aiNeighbourhood, isNull);
    expect(older.aiCity, isNull);
    expect(older.aiRegion, isNull);

    // And a new post can use them.
    await db.into(db.savedPosts).insert(
          SavedPostsCompanion.insert(
            title: 'Rainy Day in Osaka City',
            caption: const Value('a hidden gem cafe in Nakazakicho'),
            creator: const Value('Sweet Rain'),
            creatorHandle: const Value('@sweetrain'),
            platform: 'youtube',
            importMethod: 'link',
            sourceId: const Value('Sf9ihvL0Usk'),
            mediaType: const Value('video'),
            aiNeighbourhood: const Value('Nakazakicho'),
            aiCity: const Value('Osaka'),
            dateSaved: DateTime.now(),
          ),
        );
    final saved = await db.select(db.savedPosts).get();
    final fresh = saved.firstWhere((row) => row.sourceId == 'Sf9ihvL0Usk');
    expect(fresh.aiNeighbourhood, 'Nakazakicho');
    expect(fresh.mediaType, 'video');
  });
}
