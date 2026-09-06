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
    final query = _db.select(_db.trips).join([
      leftOuterJoin(
        _db.savedPosts,
        _db.savedPosts.tripId.equalsExp(_db.trips.id),
      ),
    ])
      ..addColumns([count])
      ..groupBy([_db.trips.id])
      ..orderBy([OrderingTerm.asc(_db.trips.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map((row) => TripSummary(row.readTable(_db.trips), row.read(count) ?? 0))
          .toList(),
    );
  }

  Future<List<Trip>> allTrips() =>
      (_db.select(_db.trips)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  Stream<Trip?> watchTrip(int id) =>
      (_db.select(_db.trips)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> createTrip(String name, int userId) {
    return _db.into(_db.trips).insert(
          TripsCompanion.insert(
            name: name,
            userId: userId,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> rename(int id, String name) {
    return (_db.update(_db.trips)..where((t) => t.id.equals(id)))
        .write(TripsCompanion(name: Value(name)));
  }

  /// Posts in the trip are kept; their `tripId` falls back to null so nothing
  /// is silently destroyed along with the trip.
  Future<void> deleteTrip(int id) async {
    await (_db.update(_db.savedPosts)..where((p) => p.tripId.equals(id)))
        .write(const SavedPostsCompanion(tripId: Value(null)));
    await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
  }

  Stream<int> watchTripCount() {
    final count = _db.trips.id.count();
    final query = _db.selectOnly(_db.trips)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }
}
