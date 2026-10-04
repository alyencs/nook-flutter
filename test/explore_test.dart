import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/categories.dart';
import 'package:nook/ai/platform_from_url.dart';
import 'package:nook/ai/post_place.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/daos/trips_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/explore/explore_catalogue.dart';
import 'package:nook/explore/save_explore_itinerary.dart';
import 'package:nook/screens/root_shell.dart';
import 'package:nook/theme/nook_theme.dart';
import 'package:nook/widgets/nook_bottom_nav.dart';

/// The itinerary catalogue, and what saving one actually writes.
///
/// The catalogue is bundled content rather than a query, so the thing worth
/// asserting is that it stays inside the vocabulary the rest of the app can
/// read: a category no screen can filter, or an image path that resolves to
/// nothing, would both fail quietly at runtime.
void main() {
  group('the catalogue', () {
    test('is not empty', () {
      expect(exploreItineraries, isNotEmpty);
    });

    test('every id is unique, so a list key cannot collide', () {
      final ids = exploreItineraries.map((it) => it.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every category is one the app can filter', () {
      for (final itinerary in exploreItineraries) {
        for (final stop in itinerary.stops) {
          expect(
            NookCategories.all,
            contains(stop.category),
            reason:
                '${itinerary.id}/${stop.title} uses "${stop.category}", which '
                'no chip or search filter offers',
          );
        }
      }
    });

    test('every image is a bundled asset, not a URL', () {
      for (final itinerary in exploreItineraries) {
        final paths = <String?>[
          itinerary.coverImage,
          ...itinerary.stops.map((stop) => stop.image),
        ].whereType<String>();
        for (final path in paths) {
          expect(path, startsWith('assets/'), reason: itinerary.id);
        }
      }
    });

    test('every itinerary has at least one stop and a day for it', () {
      for (final itinerary in exploreItineraries) {
        expect(itinerary.stops, isNotEmpty, reason: itinerary.id);
        expect(itinerary.days, greaterThan(0), reason: itinerary.id);
        expect(itinerary.dayNumbers, isNotEmpty, reason: itinerary.id);
        for (final day in itinerary.dayNumbers) {
          expect(day, inInclusiveRange(1, itinerary.days), reason: itinerary.id);
          expect(itinerary.stopsOnDay(day), isNotEmpty, reason: itinerary.id);
        }
      }
    });

    test('coordinates come as a pair, inside the real ranges', () {
      for (final itinerary in exploreItineraries) {
        for (final stop in itinerary.stops) {
          expect(
            stop.latitude == null,
            stop.longitude == null,
            reason: '${itinerary.id}/${stop.title} has half a coordinate',
          );
          if (stop.hasCoordinates) {
            expect(stop.latitude!.abs(), lessThanOrEqualTo(90));
            expect(stop.longitude!.abs(), lessThanOrEqualTo(180));
          }
        }
      }
    });

    test('the duration and stop labels read as English', () {
      final oneDay = exploreItineraries.firstWhere(
        (it) => it.days == 1,
        orElse: () => exploreItineraries.first,
      );
      expect(oneDay.durationLabel, matches(RegExp(r'^\d+ days?$')));
      expect(oneDay.stopsLabel, matches(RegExp(r'^\d+ stops?$')));
    });
  });

  group('saving one', () {
    late NookDatabase db;
    late AppScope scope;

    setUp(() async {
      db = NookDatabase.forTesting(NativeDatabase.memory());
      await db.customStatement('PRAGMA foreign_keys = ON');
      scope = AppScope(
        db: db,
        tab: ValueNotifier<int>(0),
        extractor: const SampleExtractor(),
        child: const SizedBox.shrink(),
      );
    });

    tearDown(() => db.close());

    final kyoto = exploreItineraries.firstWhere(
      (it) => it.id == 'kyoto-three-days',
    );

    test('becomes one trip and one post per stop', () async {
      final before = await TripsDao(db).allTrips();
      final tripId = await saveExploreItinerary(scope, kyoto);
      expect(tripId, isNotNull);

      final after = await TripsDao(db).allTrips();
      expect(after, hasLength(before.length + 1));

      final trip = after.firstWhere((t) => t.id == tripId);
      expect(trip.name, kyoto.title);
      expect(trip.colorId, kyoto.colour.id);

      final posts = await PostsDao(db).watchByTrip(tripId!).first;
      expect(posts, hasLength(kyoto.stops.length));
    });

    test('carries the fields the detail screens draw', () async {
      final tripId = await saveExploreItinerary(scope, kyoto);
      final posts = await PostsDao(db).watchByTrip(tripId!).first;

      final shrine = posts.firstWhere(
        (p) => p.aiPlaceName == 'Fushimi Inari Taisha',
      );
      expect(shrine.aiDestination, kyoto.destination);
      expect(shrine.aiCountry, kyoto.country);
      expect(shrine.aiCity, 'Kyoto');
      expect(shrine.aiCategory, 'Scenery');
      expect(shrine.aiBestTime, kyoto.bestTime);
      expect(shrine.aiBudgetNote, kyoto.budgetNote);
      expect(shrine.aiLatitude, closeTo(34.9671, 0.001));
      expect(shrine.aiNeighbourhood, 'Fushimi');
      expect(shrine.thumbnailUrl, startsWith('assets/'));
      expect(PostHighlights.decode(shrine.aiHighlights), isNotEmpty);
      expect(shrine.importMethod, 'note');
      expect(shrine.platform, NookPlatform.other);
      expect(
        shrine.originalUrl,
        isNull,
        reason: 'a curated stop has no post behind it to link to',
      );
    });

    test('a stop with no photograph borrows the cover', () async {
      final tripId = await saveExploreItinerary(scope, kyoto);
      final posts = await PostsDao(db).watchByTrip(tripId!).first;

      final imageless = kyoto.stops.where((s) => s.image == null);
      expect(imageless, isNotEmpty, reason: 'the fixture needs one to test');

      for (final stop in imageless) {
        final saved = posts.firstWhere((p) => p.title == stop.title);
        expect(saved.thumbnailUrl, kyoto.coverImage);
      }
    });

    test('is reported as already saved afterwards, and not before', () async {
      expect(await exploreItinerarySaved(scope, kyoto), isFalse);
      await saveExploreItinerary(scope, kyoto);
      expect(await exploreItinerarySaved(scope, kyoto), isTrue);
    });

    test('saving twice makes two trips, sharing nothing', () async {
      final first = await saveExploreItinerary(scope, kyoto);
      final second = await saveExploreItinerary(scope, kyoto);
      expect(second, isNot(first));

      final firstPosts = await PostsDao(db).watchByTrip(first!).first;
      final secondPosts = await PostsDao(db).watchByTrip(second!).first;
      expect(firstPosts, hasLength(kyoto.stops.length));
      expect(secondPosts, hasLength(kyoto.stops.length));
      expect(
        firstPosts.map((p) => p.id).toSet().intersection(
          secondPosts.map((p) => p.id).toSet(),
        ),
        isEmpty,
        reason: 'the second copy must not adopt the first copy rows',
      );
    });

    test('every catalogue entry saves without throwing', () async {
      for (final itinerary in exploreItineraries) {
        final tripId = await saveExploreItinerary(scope, itinerary);
        expect(tripId, isNotNull, reason: itinerary.id);
        final posts = await PostsDao(db).watchByTrip(tripId!).first;
        expect(posts, hasLength(itinerary.stops.length), reason: itinerary.id);
      }
    });
  });

  group('the journey', () {
    late NookDatabase db;

    setUp(() => db = NookDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          db: db,
          tab: ValueNotifier<int>(NookTabs.trips),
          extractor: const SampleExtractor(),
          child: MaterialApp(theme: NookTheme.theme, home: child),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Drift schedules a zero-duration timer when a stream query is cancelled,
    // and an outstanding timer at teardown fails the test.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    // The Save button carries a spinner while it writes, and a spinner
    // schedules a frame for ever: pumpAndSettle cannot settle against one. The
    // write is a handful of inserts into an in-memory database, so a bounded
    // pump is both sufficient and terminating.
    Future<void> pumpSave(WidgetTester tester) async {
      await tester.tap(find.text('Save to My Trips'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('Trips reaches the catalogue, and a card reaches its detail', (
      tester,
    ) async {
      await pump(tester, const RootShell());

      expect(find.text('Explore itineraries'), findsOneWidget);
      await tester.tap(find.text('See All'));
      await tester.pumpAndSettle();

      expect(find.text('Itineraries to borrow'), findsOneWidget);
      for (final itinerary in exploreItineraries) {
        expect(find.text(itinerary.title), findsWidgets, reason: itinerary.id);
      }

      await tester.tap(find.text('Three Days in Kyoto').first);
      await tester.pumpAndSettle();

      expect(find.text('Save to My Trips'), findsOneWidget);
      expect(find.text('DAY 1'), findsOneWidget);
      expect(find.text('Fushimi Inari before the crowds'), findsOneWidget);
      expect(find.text('Best Time to Visit'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('saving adds the trip and comes back to the list', (
      tester,
    ) async {
      await pump(tester, const RootShell());
      await tester.tap(find.text('See All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Three Days in Kyoto').first);
      await tester.pumpAndSettle();

      await pumpSave(tester);

      // Back on the catalogue, with the confirmation over it.
      expect(find.text('Itineraries to borrow'), findsOneWidget);
      expect(
        find.text('Added "Three Days in Kyoto" to your trips'),
        findsOneWidget,
      );

      // Read through a Future, not a stream: testWidgets runs its body in a
      // fake-async zone, and awaiting a Drift stream query there never returns
      // because the clock only advances while the tester pumps. What each row
      // carries is asserted in the save group above, where that is not a
      // constraint.
      final kyoto = exploreItineraries.firstWhere(
        (it) => it.id == 'kyoto-three-days',
      );
      final saved = (await TripsDao(db).allTrips())
          .where((t) => t.name == kyoto.title);
      expect(saved, hasLength(1));
      await unmount(tester);
    });

    testWidgets('saving the same itinerary twice asks first', (tester) async {
      final kyoto = exploreItineraries.firstWhere(
        (it) => it.id == 'kyoto-three-days',
      );

      await pump(tester, const RootShell());
      await tester.tap(find.text('See All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kyoto.title).first);
      await tester.pumpAndSettle();
      await pumpSave(tester);

      // Second time round the dialog stands in the way.
      await tester.tap(find.text(kyoto.title).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to My Trips'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Already in your trips'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        (await TripsDao(db).allTrips()).where((t) => t.name == kyoto.title),
        hasLength(1),
        reason: 'declining must not write a second trip',
      );
      await unmount(tester);
    });
  });
}
