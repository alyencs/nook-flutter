import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/daos/trips_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/profile/recently_deleted_screen.dart';
import 'package:nook/theme/nook_theme.dart';

/// The Recently Deleted screen, as a person meets it.
void main() {
  late NookDatabase db;
  late PostsDao posts;
  late TripsDao trips;
  late int userId;

  setUp(() async {
    db = NookDatabase.forTesting(NativeDatabase.memory());
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

  /// Database work inside a `testWidgets` body runs in the fake-async zone and
  /// never completes. `runAsync` steps outside it for the duration.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() work) async {
    final result = await tester.runAsync(work);
    return result as T;
  }

  /// Tears the tree down inside the test's own zone.
  ///
  /// Drift schedules a zero-duration timer when a query stream is cancelled.
  /// Left to teardown, that timer is still pending when the fake clock stops,
  /// and the run reports "pending timers" instead of finishing.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> show(WidgetTester tester) async {
    final tab = ValueNotifier<int>(0);
    addTearDown(tab.dispose);
    await tester.pumpWidget(
      AppScope(
        db: db,
        extractor: const SampleExtractor(),
        tab: tab,
        child: MaterialApp(
          theme: NookTheme.theme,
          home: const RecentlyDeletedScreen(),
        ),
      ),
    );
    // Bounded: the staggered entrance animates, and pumpAndSettle would wait
    // on it plus every image retry.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<int> addPost({int? tripId, String title = 'Kyoto cafes'}) {
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

  testWidgets('an empty bin says so rather than showing a bare screen', (
    tester,
  ) async {
    await show(tester);

    expect(find.text('Nothing deleted'), findsOneWidget);
    // Nothing to empty, so no destructive action is offered.
    expect(find.text('Empty'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a deleted post is listed, with both ways out', (tester) async {
    await real(tester, () async {
      final id = await addPost();
      await posts.deletePost(id);
    });

    await show(tester);

    expect(find.text('Kyoto cafes'), findsOneWidget);
    expect(find.text('Deleted today'), findsOneWidget);
    expect(find.byTooltip('Restore'), findsOneWidget);
    expect(find.byTooltip('Delete permanently'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('restoring removes it from the list and puts the row back', (
    tester,
  ) async {
    final tripId = await real(tester, () async {
      final tripId = await trips.createTrip('Japan 2027', userId);
      final id = await addPost(tripId: tripId);
      await posts.deletePost(id);
      return tripId;
    });

    await show(tester);
    expect(find.text('Kyoto cafes'), findsOneWidget);

    await tester.tap(find.byTooltip('Restore'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('Nothing deleted'), findsOneWidget);
    // And it is genuinely back where it was, not merely off this screen —
    // checked at the DAO level in recently_deleted_test.dart.
    final back = await real(tester, () => posts.watchByTrip(tripId).first);
    expect(back, hasLength(1));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a deleted trip says how many posts will come back with it', (
    tester,
  ) async {
    await real(tester, () async {
      final tripId = await trips.createTrip('Japan 2027', userId);
      await addPost(tripId: tripId);
      await addPost(tripId: tripId, title: 'Osaka food');
      await trips.deleteTrip(tripId);
    });

    await show(tester);

    expect(find.text('Japan 2027'), findsOneWidget);
    expect(
      find.textContaining('2 posts will return to it'),
      findsOneWidget,
      reason: 'restoring a trip is about the posts, not the folder',
    );
    // The posts themselves were never deleted, so they are not listed here.
    expect(find.text('Osaka food'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('trips and posts are shown under their own headings', (
    tester,
  ) async {
    await real(tester, () async {
      final tripId = await trips.createTrip('Japan 2027', userId);
      final id = await addPost();
      await posts.deletePost(id);
      await trips.deleteTrip(tripId);
    });

    await show(tester);

    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Japan 2027'), findsOneWidget);
    expect(find.text('Kyoto cafes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the retention window is stated, not left to be discovered', (
    tester,
  ) async {
    await show(tester);
    expect(find.textContaining('30 days'), findsOneWidget);
    await unmount(tester);
  });
}
