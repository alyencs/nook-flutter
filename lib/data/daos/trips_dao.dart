import 'package:drift/drift.dart';

import '../database.dart';

/// A trip plus the number of posts in it.
///
/// The proposal lists `item_count` as a column. Counting it here instead means
/// the number on a trip card is always the number of rows behind it.
class TripSummary {
  const TripSummary(this.trip, this.itemCount);

  final Trip trip;
  final int itemCount;
}

class TripsDao {
  TripsDao(this._db);

  final NookDatabase _db;

  /// Oldest first, which is the order the mockup draws: Japan 2027, Weekend
  /// Getaways, Someday List, Europe Backpacking.
  Stream<List<TripSummary>> watchTripSummaries() {
    final count = _db.savedPosts.id.count();
    final query =
        _db.select(_db.trips).join([
            // The join condition, not a where: a deleted post must drop out of the
            // count without dropping its whole trip out of the list.
            leftOuterJoin(
              _db.savedPosts,
              _db.savedPosts.tripId.equalsExp(_db.trips.id) &
                  _db.savedPosts.deletedAt.isNull(),
            ),
          ])
          ..addColumns([count])
          ..where(_db.trips.deletedAt.isNull())
          ..groupBy([_db.trips.id])
          ..orderBy([OrderingTerm.asc(_db.trips.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) =>
                TripSummary(row.readTable(_db.trips), row.read(count) ?? 0),
          )
          .toList(),
    );
  }

  Future<List<Trip>> allTrips() =>
      (_db.select(_db.trips)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// Null for a deleted trip as well as a missing one, which is what makes a
  /// post whose trip is in Recently Deleted read as unfiled everywhere without
  /// a single screen having to know about deletion.
  Stream<Trip?> watchTrip(int id) => (_db.select(
    _db.trips,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  Future<int> createTrip(String name, int userId) {
    return _db
        .into(_db.trips)
        .insert(
          TripsCompanion.insert(
            name: name,
            userId: userId,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> rename(int id, String name) {
    return (_db.update(
      _db.trips,
    )..where((t) => t.id.equals(id))).write(TripsCompanion(name: Value(name)));
  }

  /// Moves the trip to Recently Deleted. The posts in it are untouched.
  ///
  /// Their `trip_id` is deliberately left pointing at this trip rather than
  /// nulled. Because [watchTrip] hides a deleted trip, those posts already read
  /// as unfiled everywhere — and because the pointer survives, restoring the
  /// trip puts the same rows back in it. Nothing is copied, so nothing can be
  /// duplicated, and a post that was moved elsewhere in the meantime stays
  /// where the person put it.
  Future<void> deleteTrip(int id) {
    return (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> restoreTrip(int id) {
    return (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
      const TripsCompanion(deletedAt: Value(null)),
    );
  }

  /// Gone for good. Here the posts really do have to let go of the trip, or
  /// the foreign key would point at a row that no longer exists.
  Future<void> deleteTripForever(int id) async {
    await (_db.update(_db.savedPosts)..where((p) => p.tripId.equals(id))).write(
      const SavedPostsCompanion(tripId: Value(null)),
    );
    await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Trip>> watchDeleted() {
    return (_db.select(_db.trips)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .watch();
  }

  /// How many posts would come back with this trip, for the restore line.
  Future<int> postsAwaiting(int tripId) async {
    final count = _db.savedPosts.id.count();
    final query = _db.selectOnly(_db.savedPosts)
      ..addColumns([count])
      ..where(
        _db.savedPosts.tripId.equals(tripId) &
            _db.savedPosts.deletedAt.isNull(),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> emptyDeleted() async {
    final rows = await (_db.select(
      _db.trips,
    )..where((t) => t.deletedAt.isNotNull())).get();
    for (final trip in rows) {
      await deleteTripForever(trip.id);
    }
  }

  Future<void> purgeDeletedBefore(DateTime cutoff) async {
    final rows =
        await (_db.select(_db.trips)..where(
              (t) =>
                  t.deletedAt.isNotNull() &
                  t.deletedAt.isSmallerThanValue(cutoff),
            ))
            .get();
    for (final trip in rows) {
      await deleteTripForever(trip.id);
    }
  }

  Stream<int> watchTripCount() {
    final count = _db.trips.id.count();
    final query = _db.selectOnly(_db.trips)
      ..addColumns([count])
      ..where(_db.trips.deletedAt.isNull());
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }
}
