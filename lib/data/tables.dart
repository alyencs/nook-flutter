import 'package:drift/drift.dart';

/// The local profile. One row, always.
///
/// There is no password column and no session: the proposal's storage decision
/// (Drift, on device, no server) means there is nothing to authenticate
/// against. This is a profile, not an account.
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Nullable, and no longer collected.
  ///
  /// Nook stores everything on the device and talks to no server, so there was
  /// never an account for an email address to identify. Onboarding now asks
  /// what to call you and nothing else. The column stays so that profiles
  /// created before this keep their data; nothing reads it.
  TextColumn get email => text().nullable()();

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

  /// When this trip was moved to Recently Deleted, or null while it is live.
  ///
  /// Deleting a trip does not touch the posts in it — that was always true, and
  /// is what the confirmation now says out loud. What changed is that the trip
  /// row itself survives too, with its posts' `trip_id` left exactly as it was,
  /// so restoring puts the same posts back in the same trip. Nothing is copied,
  /// so nothing can be duplicated.
  DateTimeColumn get deletedAt => dateTime().nullable()();
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

  /// The post's own words — a YouTube description, a TikTok or Instagram
  /// caption. Separate from [title], because a title is a line and a caption is
  /// a paragraph, and search should match either.
  TextColumn get caption => text().nullable()();

  /// The @handle, where the platform has one. [creator] is the display name.
  TextColumn get creatorHandle => text().nullable()();

  /// The platform's own id: a YouTube video id, an Instagram shortcode. Held so
  /// that it is available as metadata and never needed as a title — showing
  /// `Sf9ihvL0Usk` where a title belongs is what this column exists to prevent.
  TextColumn get sourceId => text().nullable()();

  /// video | image | carousel | unknown. Not assumed: a photo post is not a
  /// video, and the badge over its thumbnail should not say so.
  TextColumn get mediaType => text().nullable()();

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

  // The location, from most specific to least. [aiDestination] stays as the
  // one-line display string composed from these; these are what make it
  // possible to store "a cafe in Nakazakicho, Osaka" rather than "Japan".
  TextColumn get aiPlaceName => text().nullable()();
  TextColumn get aiAddress => text().nullable()();
  TextColumn get aiNeighbourhood => text().nullable()();
  TextColumn get aiCity => text().nullable()();
  TextColumn get aiRegion => text().nullable()();

  /// Specific places the source named — the five cafes in "5 Cafes in Kyoto".
  ///
  /// A JSON array of `{name, kind, area, note}`, because the count varies per
  /// post and a column per place would be a schema that depends on content.
  /// Read and written through [PostPlace].
  TextColumn get aiPlaces => text().nullable()();

  /// Activities, recommendations and tips the source gave, as a JSON array of
  /// strings. Prices and seasons keep their own columns above.
  TextColumn get aiHighlights => text().nullable()();

  /// Where the destination is, so it can be pinned on a map. Null whenever the
  /// destination is null or too vague to place — "Southeast Asia" has no single
  /// point — in which case Travel Details shows the placeholder instead.
  RealColumn get aiLatitude => real().nullable()();
  RealColumn get aiLongitude => real().nullable()();

  IntColumn get tripId => integer().nullable().customConstraint(
    'NULL REFERENCES trips(id) ON DELETE SET NULL',
  )();
  TextColumn get personalNote => text().nullable()();
  DateTimeColumn get dateSaved => dateTime()();

  /// Drives the "Recently Viewed" section on Home. See decision 7.
  DateTimeColumn get lastViewedAt => dateTime().nullable()();

  /// Drawn as "Last edited …" on the Personal Notes screen. See decision 7.
  DateTimeColumn get noteEditedAt => dateTime().nullable()();

  /// When this post was moved to Recently Deleted, or null while it is live.
  ///
  /// Every query that feeds a screen filters on this, so a deleted post leaves
  /// Home, search, its trip and the counts at once while the row — and its
  /// extraction, its note, its trip membership — stays intact for restoring.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DataClassName('RecentSearch')
/// Backs the "Recent Searches" list and its per-item delete. See decision 7.
class RecentSearches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime()();
}

/// The switches on the Settings screen.
///
/// A key/value table rather than columns, so adding a setting does not mean a
/// schema migration. Anything absent falls back to [NookSettings.defaults].
class AppSettings extends Table {
  TextColumn get name => text()();
  BoolColumn get enabled => boolean()();

  @override
  Set<Column> get primaryKey => {name};
}
