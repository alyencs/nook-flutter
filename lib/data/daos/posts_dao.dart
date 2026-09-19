import 'package:drift/drift.dart';

import '../database.dart';

class PostsDao {
  PostsDao(this._db);

  final NookDatabase _db;

  Stream<List<SavedPost>> watchRecentSaves({int limit = 10}) {
    return (_db.select(_db.savedPosts)
          ..orderBy([(p) => OrderingTerm.desc(p.dateSaved)])
          ..limit(limit))
        .watch();
  }

  /// Posts that have actually been opened, most recent first. Backed by
  /// `last_viewed_at`, so an untouched library shows nothing here rather than
  /// repeating Recent Saves under a different heading.
  Stream<List<SavedPost>> watchRecentlyViewed({int limit = 10}) {
    return (_db.select(_db.savedPosts)
          ..where((p) => p.lastViewedAt.isNotNull())
          ..orderBy([(p) => OrderingTerm.desc(p.lastViewedAt)])
          ..limit(limit))
        .watch();
  }

  Stream<List<SavedPost>> watchAll() {
    return (_db.select(_db.savedPosts)
          ..orderBy([(p) => OrderingTerm.desc(p.dateSaved)]))
        .watch();
  }

  Stream<List<SavedPost>> watchByTrip(int tripId) {
    return (_db.select(_db.savedPosts)
          ..where((p) => p.tripId.equals(tripId))
          ..orderBy([(p) => OrderingTerm.desc(p.dateSaved)]))
        .watch();
  }

  Stream<SavedPost?> watchPost(int id) =>
      (_db.select(_db.savedPosts)..where((p) => p.id.equals(id)))
          .watchSingleOrNull();

  /// Feature #4. Matches title, creator, destination, country, category and the
  /// personal note, so "cafes in Kyoto" finds a post whose title says cafes and
  /// whose detected destination says Kyoto.
  Stream<List<SavedPost>> search(String term) {
    final q = '%${term.trim().toLowerCase()}%';
    return (_db.select(_db.savedPosts)
          ..where(
            (p) =>
                p.title.lower().like(q) |
                p.creator.lower().like(q) |
                p.aiDestination.lower().like(q) |
                p.aiCountry.lower().like(q) |
                p.aiCategory.lower().like(q) |
                p.personalNote.lower().like(q),
          )
          ..orderBy([(p) => OrderingTerm.desc(p.dateSaved)]))
        .watch();
  }

  Future<int> insertPost(SavedPostsCompanion post) =>
      _db.into(_db.savedPosts).insert(post);

  Future<void> markViewed(int id) {
    return (_db.update(_db.savedPosts)..where((p) => p.id.equals(id))).write(
      SavedPostsCompanion(lastViewedAt: Value(DateTime.now())),
    );
  }

  /// Feature #5.
  Future<void> updateNote(int id, String note) {
    return (_db.update(_db.savedPosts)..where((p) => p.id.equals(id))).write(
      SavedPostsCompanion(
        personalNote: Value(note.isEmpty ? null : note),
        noteEditedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> moveToTrip(int id, int? tripId) {
    return (_db.update(_db.savedPosts)..where((p) => p.id.equals(id)))
        .write(SavedPostsCompanion(tripId: Value(tripId)));
  }

  Future<void> updateDetected(int id, {String? destination, String? category}) {
    return (_db.update(_db.savedPosts)..where((p) => p.id.equals(id))).write(
      SavedPostsCompanion(
        aiDestination: Value(destination),
        aiCategory: Value(category),
      ),
    );
  }

  Future<void> deletePost(int id) =>
      (_db.delete(_db.savedPosts)..where((p) => p.id.equals(id))).go();

  Stream<int> watchPostCount() {
    final count = _db.savedPosts.id.count();
    final query = _db.selectOnly(_db.savedPosts)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }
}
