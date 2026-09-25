import 'package:drift/drift.dart';

import '../database.dart';

class PostsDao {
  PostsDao(this._db);

  final NookDatabase _db;

  /// Every read below filters on `deleted_at`, so a post moved to Recently
  /// Deleted leaves Home, search, its trip and the counts in one write, while
  /// the row keeps everything needed to put it back.
  Stream<List<SavedPost>> watchRecentSaves({int limit = 10}) {
    return (_db.select(_db.savedPosts)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.desc(p.dateSaved)])
          ..limit(limit))
        .watch();
  }

  /// Posts that have actually been opened, most recent first. Backed by
  /// `last_viewed_at`, so an untouched library shows nothing here rather than
  /// repeating Recent Saves under a different heading.
  Stream<List<SavedPost>> watchRecentlyViewed({int limit = 10}) {
    return (_db.select(_db.savedPosts)
          ..where((p) => p.lastViewedAt.isNotNull() & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.desc(p.lastViewedAt)])
          ..limit(limit))
        .watch();
  }

  Stream<List<SavedPost>> watchAll() {
    return (_db.select(_db.savedPosts)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.desc(p.dateSaved)]))
        .watch();
  }

  Stream<List<SavedPost>> watchByTrip(int tripId) {
    return (_db.select(_db.savedPosts)
          ..where((p) => p.tripId.equals(tripId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.desc(p.dateSaved)]))
        .watch();
  }

  /// Deliberately not filtered: a post being viewed while it is deleted should
  /// still resolve, so the screen can close itself rather than throw.
  Stream<SavedPost?> watchPost(int id) => (_db.select(
    _db.savedPosts,
  )..where((p) => p.id.equals(id))).watchSingleOrNull();

  /// Feature #4. Matches title, creator, destination, country, category and the
  /// personal note, so "cafes in Kyoto" finds a post whose title says cafes and
  /// whose detected destination says Kyoto.
  Stream<List<SavedPost>> search(String term) {
    final q = '%${term.trim().toLowerCase()}%';
    return (_db.select(_db.savedPosts)
          ..where(
            (p) =>
                p.deletedAt.isNull() &
                (p.title.lower().like(q) |
                    p.creator.lower().like(q) |
                    p.aiDestination.lower().like(q) |
                    p.aiCountry.lower().like(q) |
                    p.aiCategory.lower().like(q) |
                    p.personalNote.lower().like(q)),
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
    return (_db.update(_db.savedPosts)..where((p) => p.id.equals(id))).write(
      SavedPostsCompanion(tripId: Value(tripId)),
    );
  }

  Future<void> updateDetected(int id, {String? destination, String? category}) {
    return (_db.update(_db.savedPosts)..where((p) => p.id.equals(id))).write(
      SavedPostsCompanion(
        aiDestination: Value(destination),
        aiCategory: Value(category),
      ),
    );
  }

  /// Moves the post to Recently Deleted.
  ///
  /// Nothing is cleared — not the trip, not the note, not the extraction — so
  /// restoring is a single write back and cannot lose anything or duplicate it.
  Future<void> deletePost(int id) {
    return (_db.update(_db.savedPosts)..where((p) => p.id.equals(id))).write(
      SavedPostsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  /// Puts it back exactly where it was, including its trip.
  Future<void> restorePost(int id) {
    return (_db.update(_db.savedPosts)..where((p) => p.id.equals(id))).write(
      const SavedPostsCompanion(deletedAt: Value(null)),
    );
  }

  /// Gone for good. Only Recently Deleted calls this.
  Future<void> deletePostForever(int id) =>
      (_db.delete(_db.savedPosts)..where((p) => p.id.equals(id))).go();

  /// Recently Deleted, newest first — the order things were thrown away in.
  Stream<List<SavedPost>> watchDeleted() {
    return (_db.select(_db.savedPosts)
          ..where((p) => p.deletedAt.isNotNull())
          ..orderBy([(p) => OrderingTerm.desc(p.deletedAt)]))
        .watch();
  }

  Future<void> emptyDeleted() =>
      (_db.delete(_db.savedPosts)..where((p) => p.deletedAt.isNotNull())).go();

  /// Drops anything past the retention window. Called when the screen opens,
  /// which is the only moment the answer can change without the app running.
  Future<void> purgeDeletedBefore(DateTime cutoff) {
    return (_db.delete(_db.savedPosts)..where(
          (p) =>
              p.deletedAt.isNotNull() & p.deletedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  Stream<int> watchPostCount() {
    final count = _db.savedPosts.id.count();
    final query = _db.selectOnly(_db.savedPosts)
      ..addColumns([count])
      ..where(_db.savedPosts.deletedAt.isNull());
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }
}
