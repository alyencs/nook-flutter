import 'package:drift/drift.dart';

import '../database.dart';

class SearchesDao {
  SearchesDao(this._db);

  final NookDatabase _db;

  Stream<List<RecentSearch>> watchRecent({int limit = 5}) {
    return (_db.select(_db.recentSearches)
          // Two searches in the same millisecond tie on the timestamp, so the
          // id breaks the tie and the newest genuinely comes first.
          ..orderBy([
            (s) => OrderingTerm.desc(s.searchedAt),
            (s) => OrderingTerm.desc(s.id),
          ])
          ..limit(limit))
        .watch();
  }

  /// Re-searching a term moves it to the top rather than duplicating it.
  Future<void> record(String query) async {
    final term = query.trim();
    if (term.isEmpty) return;
    await (_db.delete(_db.recentSearches)
          ..where((s) => s.query.lower().equals(term.toLowerCase())))
        .go();
    await _db.into(_db.recentSearches).insert(
          RecentSearchesCompanion.insert(
            query: term,
            searchedAt: DateTime.now(),
          ),
        );
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.recentSearches)..where((s) => s.id.equals(id))).go();

  Future<void> clear() => _db.delete(_db.recentSearches).go();
}
