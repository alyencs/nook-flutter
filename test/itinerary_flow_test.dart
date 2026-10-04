import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/itinerary.dart';
import 'package:nook/ai/itinerary_generator.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/ai/sample_itinerary_generator.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/daos/trips_dao.dart';
import 'package:nook/data/daos/users_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/explore/explore_itineraries_screen.dart';
import 'package:nook/screens/explore/itinerary_plan_screen.dart';
import 'package:nook/screens/root_shell.dart';
import 'package:nook/theme/nook_theme.dart';
import 'package:nook/widgets/nook_bottom_nav.dart';

/// The journey: Trips, a trip, a duration, a plan.
///
/// Driven through the real widgets, because the point of this feature is that
/// the taps connect and the number the traveller chose is the number of days
/// they get.

/// A planner that never answers, so the loading state can be looked at.
class _HangingGenerator implements ItineraryGenerator {
  final _completer = Completer<GeneratedItinerary>();

  @override
  bool get isLive => true;

  @override
  Future<GeneratedItinerary> generate(
    ItineraryRequest request, {
    ItineraryStage? onStage,
  }) {
    onStage?.call(ItineraryPhase.planning);
    return _completer.future;
  }
}

/// A planner that fails the way the service does.
class _FailingGenerator implements ItineraryGenerator {
  _FailingGenerator([this.message = 'The service stayed busy.']);

  final String message;
  int calls = 0;

  @override
  bool get isLive => true;

  @override
  Future<GeneratedItinerary> generate(
    ItineraryRequest request, {
    ItineraryStage? onStage,
  }) async {
    calls++;
    throw ItineraryException(message);
  }
}

/// A planner that throws something that is not an [ItineraryException].
class _BrokenGenerator implements ItineraryGenerator {
  @override
  bool get isLive => true;

  @override
  Future<GeneratedItinerary> generate(
    ItineraryRequest request, {
    ItineraryStage? onStage,
  }) async => throw StateError('unexpected');
}

/// Counts how many times it was asked, for the duplicate-tap check.
class _CountingGenerator implements ItineraryGenerator {
  int calls = 0;

  @override
  bool get isLive => false;

  @override
  Future<GeneratedItinerary> generate(
    ItineraryRequest request, {
    ItineraryStage? onStage,
  }) {
    calls++;
    return const SampleItineraryGenerator().generate(
      request,
      onStage: onStage,
    );
  }
}

void main() {
  late NookDatabase db;

  setUp(() {
    db = NookDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ItineraryGenerator? itinerary,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 9000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        db: db,
        tab: ValueNotifier<int>(NookTabs.trips),
        extractor: const SampleExtractor(),
        itinerary: itinerary,
        child: MaterialApp(theme: NookTheme.theme, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Bounded pumps rather than pumpAndSettle.
  ///
  /// The waiting indicator animates on a repeating controller and the Generate
  /// button carries a spinner, so there is always another frame scheduled
  /// while a plan is being built and pumpAndSettle would never return.
  Future<void> advance(WidgetTester tester, {int frames = 14}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// Counts the "Day N" headings actually on screen.
  int daysShown(WidgetTester tester) {
    var count = 0;
    for (var day = 1; day <= 12; day++) {
      if (find.text('DAY $day').evaluate().isNotEmpty) count++;
    }
    return count;
  }

  Future<void> openPlan(WidgetTester tester, {String trip = 'Japan 2027'}) async {
    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(trip).first);
    await tester.pumpAndSettle();
  }

  testWidgets('Trips reaches the planner and lists what can be planned', (
    tester,
  ) async {
    await pump(tester, const RootShell());

    expect(find.text('Explore itineraries'), findsOneWidget);
    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();

    expect(find.text('Plan from what you saved'), findsOneWidget);
    for (final trip in [
      'Japan 2027',
      'Weekend Getaways',
      'Someday List',
      'Europe Backpacking',
    ]) {
      expect(find.text(trip), findsWidgets, reason: trip);
    }
    expect(find.textContaining('saved posts to plan from'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('a trip shows what the plan will be built from', (tester) async {
    await pump(tester, const RootShell());
    await openPlan(tester);

    expect(find.text('HOW LONG IS THE TRIP'), findsOneWidget);
    expect(find.text('3 days'), findsWidgets);
    expect(find.textContaining('saved'), findsWidgets);
    expect(find.text('Generate Itinerary'), findsOneWidget);
    // The posts themselves are listed, so it is obvious where days come from.
    expect(find.text('5 Hidden Cafes in Kyoto'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('three days generates exactly three days from the posts', (
    tester,
  ) async {
    await pump(tester, const RootShell());
    await openPlan(tester);

    await tester.tap(find.text('3 days').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Itinerary'));
    await advance(tester);

    expect(daysShown(tester), 3);
    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('Change number of days'), findsOneWidget);

    // Built from the saved posts rather than from the destination's reputation.
    expect(find.textContaining('Nishiki Market'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('five days generates five, and the choice is what changed', (
    tester,
  ) async {
    await pump(tester, const RootShell());
    await openPlan(tester);

    await tester.tap(find.text('5 days').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Itinerary'));
    await advance(tester);

    expect(daysShown(tester), 5);
    expect(find.text('5 days'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('one day is a day, not "1 days"', (tester) async {
    await pump(tester, const RootShell());
    await openPlan(tester);

    await tester.tap(find.text('1 day').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Itinerary'));
    await advance(tester);

    expect(daysShown(tester), 1);
    await unmount(tester);
  });

  testWidgets('changing the duration and generating again replans', (
    tester,
  ) async {
    await pump(tester, const RootShell());
    await openPlan(tester);

    await tester.tap(find.text('2 days').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Itinerary'));
    await advance(tester);
    expect(daysShown(tester), 2);

    await tester.tap(find.text('Change number of days'));
    await tester.pumpAndSettle();

    expect(find.text('HOW LONG IS THE TRIP'), findsOneWidget);
    await tester.tap(find.text('4 days').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Itinerary'));
    await advance(tester);

    expect(daysShown(tester), 4);
    await unmount(tester);
  });

  testWidgets('the wait is shown, with a way to abandon it', (tester) async {
    final hanging = _HangingGenerator();
    await pump(tester, const RootShell(), itinerary: hanging);
    await openPlan(tester);

    await tester.tap(find.text('Generate Itinerary'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Planning your days…'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(daysShown(tester), 0);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Planning cancelled.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a failure explains itself and offers both ways out', (
    tester,
  ) async {
    final failing = _FailingGenerator('The service stayed busy. Try again.');
    await pump(tester, const RootShell(), itinerary: failing);
    await openPlan(tester);

    await tester.tap(find.text('Generate Itinerary'));
    await advance(tester);

    expect(find.text('The service stayed busy. Try again.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Change number of days'), findsWidgets);
    expect(daysShown(tester), 0);

    await tester.tap(find.text('Try Again'));
    await advance(tester);
    expect(failing.calls, 2, reason: 'Try Again asks again');
    await unmount(tester);
  });

  testWidgets('an unexpected error is still a message, not a crash', (
    tester,
  ) async {
    await pump(tester, const RootShell(), itinerary: _BrokenGenerator());
    await openPlan(tester);

    await tester.tap(find.text('Generate Itinerary'));
    await advance(tester);

    expect(find.textContaining("couldn't build an itinerary"), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('two taps on Generate open one plan, not two', (tester) async {
    final hanging = _HangingGenerator();
    await pump(tester, const RootShell(), itinerary: hanging);
    await openPlan(tester);

    // Both taps land before a frame is pumped, which is what a double tap is.
    await tester.tap(find.text('Generate Itinerary'));
    await tester.tap(find.text('Generate Itinerary'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Planning your days…'),
      findsOneWidget,
      reason: 'two result routes would show two indicators',
    );
    await unmount(tester);
  });

  testWidgets('regenerating asks again and replaces the plan', (tester) async {
    final counting = _CountingGenerator();
    await pump(tester, const RootShell(), itinerary: counting);
    await openPlan(tester);

    await tester.tap(find.text('Generate Itinerary'));
    await advance(tester);
    expect(counting.calls, 1);
    expect(daysShown(tester), 3);

    await tester.tap(find.text('Regenerate'));
    await advance(tester);

    expect(counting.calls, 2);
    expect(daysShown(tester), 3, reason: 'still three days after a replan');
    await unmount(tester);
  });

  testWidgets('leaving while it is planning does not throw', (tester) async {
    await pump(tester, const RootShell(), itinerary: _HangingGenerator());
    await openPlan(tester);

    await tester.tap(find.text('Generate Itinerary'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Planning your days…'), findsOneWidget);

    // Torn down while the generator is still waiting, which is what leaving
    // the screen looks like to a pending future.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a trip with nothing saved says so instead of planning', (
    tester,
  ) async {
    final user = await UsersDao(db).currentUser();
    final empty = await TripsDao(db).createTrip('Blank Trip', user!.id);

    await pump(tester, ItineraryPlanScreen(tripId: empty));

    expect(find.text('Nothing saved to this trip yet'), findsOneWidget);
    expect(find.text('Save a Post'), findsOneWidget);
    expect(find.text('Generate Itinerary'), findsNothing);
    await unmount(tester);
  });

  testWidgets('the planner list is reachable on its own', (tester) async {
    await pump(tester, const ExploreItinerariesScreen());

    expect(find.text('Explore Itinerary'), findsOneWidget);
    expect(find.text('Plan from what you saved'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('existing trips and saved posts still work', (tester) async {
    await pump(tester, const RootShell());

    // The Trips tab still lists its trips and their counts.
    expect(find.text('Your Trips'), findsOneWidget);
    expect(find.text('Japan 2027'), findsWidgets);

    // A Future, not a stream: awaiting a Drift stream query inside
    // testWidgets never returns, because the fake clock only advances while
    // the tester pumps.
    final trips = await TripsDao(db).allTrips();
    expect(trips, hasLength(4));
    await unmount(tester);
  });
}
