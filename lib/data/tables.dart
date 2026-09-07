import 'package:drift/drift.dart';

/// The local profile. One row, always.
///
/// There is no password column and no session: the proposal's storage decision
/// (Drift, on device, no server) means there is nothing to authenticate
/// against. This is a profile, not an account.
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text()();

  /// A base64 data URI. `image_picker` returns bytes rather than a path on the
  /// web, and the image never leaves the device either way.
  TextColumn get profilePicture => text().nullable()();
}

/// Formerly "collections". A saved post belongs to exactly one trip.
///
/// The proposal lists an `item_count` field here. It is computed by
/// [TripsDao.watchTripSummaries] instead of stored, so the number on a trip
/// card can never disagree with the rows behind it.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get userId =>
      integer().customConstraint('NOT NULL REFERENCES users(id)')();
  DateTimeColumn get createdAt => dateTime()();
}

class SavedPosts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get creator => text().nullable()();

  /// tiktok | instagram | facebook | youtube | other. Parsed from the URL host,
  /// not asked of the model.
  TextColumn get platform => text()();

  /// Null when [importMethod] is `note`.
  TextColumn get originalUrl => text().nullable()();

  /// link | note
  TextColumn get importMethod => text()();
  TextColumn get thumbnailUrl => text().nullable()();

  // --- Extraction results. Every one may be null: the proposal's second risk
  // is that a destination comes back vague or absent, so every screen renders
  // an em dash rather than assuming a value.
  TextColumn get aiDestination => text().nullable()();
  TextColumn get aiCategory => text().nullable()();
  TextColumn get aiSummary => text().nullable()();

  // Added for the Travel Details screen, which draws all three. See decision 3
  // in docs/07-build-plan.md.
  TextColumn get aiCountry => text().nullable()();
  TextColumn get aiBestTime => text().nullable()();
  TextColumn get aiBudgetNote => text().nullable()();

  /// Where the destination is, so it can be pinned on a map. Null whenever the
  /// destination is null or too vague to place — "Southeast Asia" has no single
  /// point — in which case Travel Details shows the placeholder instead.
  RealColumn get aiLatitude => real().nullable()();
  RealColumn get aiLongitude => real().nullable()();

  IntColumn get tripId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES trips(id) ON DELETE SET NULL')();
  TextColumn get personalNote => text().nullable()();
  DateTimeColumn get dateSaved => dateTime()();

  /// Drives the "Recently Viewed" section on Home. See decision 7.
  DateTimeColumn get lastViewedAt => dateTime().nullable()();

  /// Drawn as "Last edited …" on the Personal Notes screen. See decision 7.
  DateTimeColumn get noteEditedAt => dateTime().nullable()();
}

@DataClassName('RecentSearch')
/// Backs the "Recent Searches" list and its per-item delete. See decision 7.
class RecentSearches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime()();
}
