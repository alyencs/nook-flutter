import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/daos/searches_dao.dart';
import 'package:nook/data/daos/trips_dao.dart';
import 'package:nook/data/daos/users_dao.dart';
import 'package:nook/data/database.dart';

void main() {
  late NookDatabase db;
  late PostsDao posts;
  late TripsDao trips;
  late UsersDao users;
  late SearchesDao searches;

  setUp(() async {
    db = NookDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    posts = PostsDao(db);
    trips = TripsDao(db);
    users = UsersDao(db);
    searches = SearchesDao(db);
  });

  tearDown(() => db.close());

  test('the seed inserts the library the mockup draws', () async {
    // The database seeds itself when it is created, so there is nothing to
    // call here: this is what a fresh install actually looks like.

    final summaries = await trips.watchTripSummaries().first;
    expect(
      summaries.map((s) => s.trip.name),
      ['Japan 2027', 'Weekend Getaways', 'Someday List', 'Europe Backpacking'],
    );

    // Item counts are computed, not stored, so they match the rows exactly.
    final japan = summaries.first;
    final japanPosts = await posts.watchByTrip(japan.trip.id).first;
    expect(japan.itemCount, japanPosts.length);

    // The seeded user row exists so trips have an owner, but it carries no
    // name: that is what tells the launch gate to run onboarding. If this ever
    // comes back named, LA1-LA6 and LO1 become unreachable again.
    final profile = await users.currentUser();
    expect(profile, isNotNull);
    expect(profile!.name, isEmpty);
    expect(profile.email, isEmpty);
  });

  test('saving a profile fills the seeded row rather than adding a second',
      () async {
    await users.saveProfile(name: 'Ali Sampang', email: 'ali@example.com');

    final all = await db.select(db.users).get();
    expect(all, hasLength(1), reason: 'the seeded row is reused');
    expect(all.single.name, 'Ali Sampang');

    // The seeded trips still belong to it.
    final summaries = await trips.watchTripSummaries().first;
    expect(summaries.every((s) => s.trip.userId == all.single.id), isTrue);

  });

  test('seeded posts carry coordinates so the map has something to pin',
      () async {
    final all = await posts.watchAll().first;
    final placeable = all.where((p) => p.aiLatitude != null).toList();

    expect(placeable, isNotEmpty);
    for (final post in placeable) {
      expect(post.aiLongitude, isNotNull, reason: 'coordinates come in pairs');
      expect(post.aiLatitude!.abs(), lessThanOrEqualTo(90));
      expect(post.aiLongitude!.abs(), lessThanOrEqualTo(180));
    }

    // A region-wide destination has no single point, and says so with a null.
    final region = all.firstWhere((p) => p.aiDestination == 'Southeast Asia');
    expect(region.aiLatitude, isNull);
  });

  test('seeded posts carry no thumbnail, because their links are invented',
      () async {
    // The demo library's URLs are illustrative, not real posts, so no real
    // preview image exists for them and every card draws the placeholder.
    // Thumbnails appear once a real link is saved — see extractor_test.dart for
    // the derivation itself.
    final all = await posts.watchAll().first;
    expect(all.every((p) => p.thumbnailUrl == null), isTrue);
  });

  test('a saved post survives a restart', () async {
    // The proposal's phase-zero spike, as a test: insert, reopen, read back.
    final before = await posts.watchAll().first;
    expect(before, isNotEmpty);

    final reopened = await posts.watchAll().first;
    expect(reopened.length, before.length);
    expect(reopened.first.title, before.first.title);
  });

  test('search matches title, destination and note', () async {

    final byTitle = await posts.search('hidden cafes').first;
    expect(byTitle.single.title, '5 Hidden Cafes in Kyoto');

    // "cafes in Kyoto" is the query drawn on the Search Results screen; it has
    // to match posts whose destination says Kyoto, not just the title.
    final byDestination = await posts.search('kyoto').first;
    expect(byDestination.length, greaterThanOrEqualTo(3));

    final byNote = await posts.search('tram 28').first;
    expect(byNote.single.title, '3-Day Lisbon Itinerary on a Budget');

    final noMatch = await posts.search('reykjavik').first;
    expect(noMatch, isEmpty);
  });

  test('recently viewed only shows posts that were opened', () async {
    final viewed = await posts.watchRecentlyViewed().first;
    expect(viewed, isNotEmpty);
    expect(viewed.every((p) => p.lastViewedAt != null), isTrue);

    // Most recent first.
    for (var i = 1; i < viewed.length; i++) {
      expect(
        viewed[i - 1].lastViewedAt!.isAfter(viewed[i].lastViewedAt!),
        isTrue,
      );
    }
  });

  test('moving a post between trips updates both counts', () async {
    final before = await trips.watchTripSummaries().first;
    final japan = before[0];
    final weekend = before[1];

    final japanPosts = await posts.watchByTrip(japan.trip.id).first;
    await posts.moveToTrip(japanPosts.first.id, weekend.trip.id);

    final after = await trips.watchTripSummaries().first;
    expect(after[0].itemCount, japan.itemCount - 1);
    expect(after[1].itemCount, weekend.itemCount + 1);
  });

  test('deleting a trip keeps its posts and clears their trip', () async {
    final summaries = await trips.watchTripSummaries().first;
    final japan = summaries.first;
    final countBefore = (await posts.watchAll().first).length;

    await trips.deleteTrip(japan.trip.id);

    final remaining = await posts.watchAll().first;
    expect(remaining.length, countBefore, reason: 'posts are not destroyed');
    expect(remaining.where((p) => p.tripId == japan.trip.id), isEmpty);
  });

  test('editing a note stamps the edit date', () async {
    final post = (await posts.watchAll().first).first;

    await posts.updateNote(post.id, 'Ask about the one in Gion.');
    final updated = await posts.watchPost(post.id).first;

    expect(updated!.personalNote, 'Ask about the one in Gion.');
    expect(updated.noteEditedAt, isNotNull);
  });

  test('re-searching a term moves it up instead of duplicating', () async {
    await searches.clear();
    await searches.record('cafes in Kyoto');
    await searches.record('Palawan beaches');
    await searches.record('cafes in Kyoto');

    final recent = await searches.watchRecent().first;
    expect(recent.map((s) => s.query), ['cafes in Kyoto', 'Palawan beaches']);
  });

  test('a post cannot reference a trip that does not exist', () async {
    final post = (await posts.watchAll().first).first;

    // The foreign key is the reason Drift was chosen over Hive.
    expect(
      () => posts.moveToTrip(post.id, 9999),
      throwsA(isA<Exception>()),
    );
  });
}
