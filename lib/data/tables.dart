import 'package:drift/drift.dart';

/// The local profile. One row, always.
///
/// No password column and no session: storage is on the device and there is no
/// server to authenticate against. This is a profile, not an account.
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Nullable, and no longer collected: there is no account for an address to
  /// identify. Kept so profiles created before this keep their data.
  TextColumn get email => text().nullable()();

  /// A base64 data URI. `image_picker` returns bytes rather than a path on the
  /// web, and the image never leaves the device either way.
  TextColumn get profilePicture => text().nullable()();
}

/// A saved post belongs to exactly one trip.
///
/// The item count is computed by [TripsDao.watchTripSummaries] rather than
/// stored, so the number on a trip card cannot disagree with the rows.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get userId =>
      integer().customConstraint('NOT NULL REFERENCES users(id)')();
  DateTimeColumn get createdAt => dateTime()();

  /// Which of the five folder colours this trip is, by [TripColor.id]. Null
  /// means "nobody chose", and the UI spreads those across the palette.
  TextColumn get colorId => text().nullable()();

  /// When this trip was moved to Recently Deleted, or null while it is live.
  ///
  /// Deleting a trip does not touch the posts in it, and the row itself
  /// survives with its posts' `trip_id` untouched, so restoring puts the same
  /// posts back in the same trip. Nothing is copied, so nothing duplicates.
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

  /// The creator's page on the platform, from oEmbed's `author_url`.
  TextColumn get creatorUrl => text().nullable()();

  /// The creator's profile picture, when the platform publishes one. YouTube
  /// only, and only with a `YOUTUBE_API_KEY`; nothing guesses one, and a post
  /// without it draws the creator's initial.
  TextColumn get creatorAvatarUrl => text().nullable()();

  /// The platform's own id: a YouTube video id, an Instagram shortcode. Held as
  /// metadata so it is never needed as a title.
  TextColumn get sourceId => text().nullable()();

  /// video | image | carousel | unknown. Not assumed: a photo post is not a
  /// video, and the badge over its thumbnail should not say so.
  TextColumn get mediaType => text().nullable()();

  // --- Extraction results. Every one may be null: a destination can come back
  // vague or absent, and every screen renders an em dash rather than assuming.
  TextColumn get aiDestination => text().nullable()();
  TextColumn get aiCategory => text().nullable()();
  TextColumn get aiSummary => text().nullable()();

  // Added for the Travel Details screen, which draws all three.
  TextColumn get aiCountry => text().nullable()();
  TextColumn get aiBestTime => text().nullable()();
  TextColumn get aiBudgetNote => text().nullable()();

  // The location, from most specific to least. [aiDestination] is the one-line
  // display string composed from these, which are what make "a cafe in
  // Nakazakicho, Osaka" storable rather than just "Japan".
  TextColumn get aiPlaceName => text().nullable()();
  TextColumn get aiAddress => text().nullable()();
  TextColumn get aiNeighbourhood => text().nullable()();
  TextColumn get aiCity => text().nullable()();
  TextColumn get aiRegion => text().nullable()();

  /// Specific places the source named — the five cafes in "5 Cafes in Kyoto".
  ///
  /// A JSON array of `{name, kind, area, note}`: the count varies per post, so
  /// a column per place would be a schema that depends on content. Read and
  /// written through [PostPlace].
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

  /// Drives the "Recently Viewed" section on Home.
  DateTimeColumn get lastViewedAt => dateTime().nullable()();

  /// Drawn as "Last edited …" on the Personal Notes screen.
  DateTimeColumn get noteEditedAt => dateTime().nullable()();

  /// When this post was moved to Recently Deleted, or null while it is live.
  ///
  /// Every screen query filters on this, so a deleted post leaves Home, search,
  /// its trip and the counts at once while the row stays intact for restoring.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DataClassName('RecentSearch')
/// Backs the "Recent Searches" list and its per-item delete.
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
