import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/daos/trips_dao.dart';
import 'package:nook/data/database.dart';

/// Recently Deleted, tested on the promise it makes: nothing is destroyed when
/// you delete, nothing is duplicated when you restore, and a deleted thing is
/// gone from every screen in the meantime.
void main() {
  late NookDatabase db;
  late PostsDao posts;
  late TripsDao trips;
  late int userId;

  setUp(() async {
    db = NookDatabase.forTesting(NativeDatabase.memory());
    // `onCreate` seeds a demo library, which is right for the app and wrong
    // here: these tests count rows, so they start from an empty table.
    await db.delete(db.savedPosts).go();
    await db.delete(db.trips).go();
    await db.delete(db.users).go();

    posts = PostsDao(db);
    trips = TripsDao(db);
    userId = await db
        .into(db.users)
        .insert(UsersCompanion.insert(name: 'Alyen'));
  });

  tearDown(() => db.close());

  Future<int> addPost({int? tripId, String title = 'A post'}) {
    return posts.insertPost(
      SavedPostsCompanion.insert(
        title: title,
        platform: 'youtube',
        importMethod: 'link',
        dateSaved: DateTime.now(),
        tripId: Value(tripId),
      ),
    );
  }

  group('deleting a post', () {
    test('takes it off every screen without destroying the row', () async {
      final id = await addPost();
      expect(await posts.watchAll().first, hasLength(1));

      await posts.deletePost(id);

      expect(await posts.watchAll().first, isEmpty, reason: 'gone from Home');
      expect(await posts.watchRecentSaves().first, isEmpty);
      expect(await posts.search('A post').first, isEmpty);
      expect(await posts.watchPostCount().first, 0);
      expect(await posts.watchDeleted().first, hasLength(1));
      // The row itself is still there, which is what makes restore possible.
      expect(await posts.watchPost(id).first, isNotNull);
    });

    test(
      'keeps the note, the trip and the extraction for the restore',
      () async {
        final tripId = await trips.createTrip('Japan 2027', userId);
        final id = await addPost(tripId: tripId);
        await posts.updateNote(id, 'the one with the cafes');

        await posts.deletePost(id);
        await posts.restorePost(id);

        final restored = await posts.watchPost(id).first;
        expect(restored!.personalNote, 'the one with the cafes');
        expect(restored.tripId, tripId, reason: 'back in the same trip');
        expect(await posts.watchByTrip(tripId).first, hasLength(1));
        expect(await posts.watchDeleted().first, isEmpty);
      },
    );

    test('restoring does not duplicate it', () async {
      final id = await addPost();
      await posts.deletePost(id);
      await posts.restorePost(id);
      await posts.restorePost(id);

      final all = await posts.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.id, id);
    });

    test('permanent delete really removes it', () async {
      final id = await addPost();
      await posts.deletePost(id);
      await posts.deletePostForever(id);

      expect(await posts.watchDeleted().first, isEmpty);
      expect(await posts.watchPost(id).first, isNull);
    });
  });

  group('deleting a trip', () {
    test('does not delete the posts inside it', () async {
      final tripId = await trips.createTrip('Japan 2027', userId);
      await addPost(tripId: tripId, title: 'Kyoto cafes');
      await addPost(tripId: tripId, title: 'Osaka food');

      await trips.deleteTrip(tripId);

      // The promise the confirmation makes.
      expect(await posts.watchAll().first, hasLength(2));
      expect(await posts.watchPostCount().first, 2);
      expect(
        await posts.watchDeleted().first,
        isEmpty,
        reason: 'the posts were not deleted along with the trip',
      );
    });

    test('leaves those posts reading as unfiled while it is gone', () async {
      final tripId = await trips.createTrip('Japan 2027', userId);
      await addPost(tripId: tripId);

      await trips.deleteTrip(tripId);

      expect(await trips.watchTrip(tripId).first, isNull);
      expect(await trips.watchTripSummaries().first, isEmpty);
      expect(await trips.watchTripCount().first, 0);
      expect(await trips.allTrips(), isEmpty);
    });

    test('restoring puts the same posts back, without copying any', () async {
      final tripId = await trips.createTrip('Japan 2027', userId);
      await addPost(tripId: tripId, title: 'Kyoto cafes');
      await addPost(tripId: tripId, title: 'Osaka food');

      await trips.deleteTrip(tripId);
      await trips.restoreTrip(tripId);

      final summaries = await trips.watchTripSummaries().first;
      expect(summaries, hasLength(1));
      expect(summaries.single.itemCount, 2, reason: 'two, not four');
      expect(await posts.watchByTrip(tripId).first, hasLength(2));
      expect(await posts.watchAll().first, hasLength(2));
    });

    test(
      'a post moved out while the trip was deleted stays where it was put',
      () async {
        final japan = await trips.createTrip('Japan 2027', userId);
        final europe = await trips.createTrip('Europe', userId);
        final id = await addPost(tripId: japan);

        await trips.deleteTrip(japan);
        await posts.moveToTrip(id, europe);
        await trips.restoreTrip(japan);

        expect(await posts.watchByTrip(japan).first, isEmpty);
        expect(await posts.watchByTrip(europe).first, hasLength(1));
      },
    );

    test('a deleted post does not count towards its trip', () async {
      final tripId = await trips.createTrip('Japan 2027', userId);
      final keep = await addPost(tripId: tripId);
      final drop = await addPost(tripId: tripId);

      await posts.deletePost(drop);

      final summaries = await trips.watchTripSummaries().first;
      expect(summaries.single.itemCount, 1);
      expect((await posts.watchByTrip(tripId).first).single.id, keep);
    });

    test(
      'permanent delete releases the posts rather than taking them',
      () async {
        final tripId = await trips.createTrip('Japan 2027', userId);
        final id = await addPost(tripId: tripId);

        await trips.deleteTrip(tripId);
        await trips.deleteTripForever(tripId);

        final post = await posts.watchPost(id).first;
        expect(post, isNotNull, reason: 'the post outlives its trip');
        expect(post!.tripId, isNull);
        expect(await trips.watchDeleted().first, isEmpty);
      },
    );
  });

  group('retention', () {
    test('purges only what is past the cutoff', () async {
      final old = await addPost(title: 'old');
      final recent = await addPost(title: 'recent');
      await posts.deletePost(old);
      await db.customStatement(
        'UPDATE saved_posts SET deleted_at = ? WHERE id = ?',
        [
          DateTime.now()
                  .subtract(const Duration(days: 40))
                  .millisecondsSinceEpoch ~/
              1000,
          old,
        ],
      );
      await posts.deletePost(recent);

      await posts.purgeDeletedBefore(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      final left = await posts.watchDeleted().first;
      expect(left, hasLength(1));
      expect(left.single.id, recent);
    });

    test('emptying clears both kinds', () async {
      final tripId = await trips.createTrip('Japan 2027', userId);
      final id = await addPost();
      await posts.deletePost(id);
      await trips.deleteTrip(tripId);

      await posts.emptyDeleted();
      await trips.emptyDeleted();

      expect(await posts.watchDeleted().first, isEmpty);
      expect(await trips.watchDeleted().first, isEmpty);
    });
  });
}
