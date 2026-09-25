import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/theme/nook_motion.dart';
import 'package:nook/theme/nook_theme.dart';
import 'package:nook/widgets/entrance.dart';
import 'package:nook/widgets/post_map.dart';
import 'package:nook/widgets/post_thumbnail.dart';
import 'package:nook/widgets/press_effect.dart';
import 'package:nook/widgets/delete_flight.dart';
import 'package:nook/widgets/flight.dart';
import 'package:nook/widgets/save_flight.dart';

/// The animations, tested for the things that break them in practice: a
/// controller outliving its widget, a timer outliving its tree, an overlay
/// entry removed twice, and a press effect that eats the tap it decorates.
///
/// Finders are anchored throughout. MaterialApp's own route transition is a
/// FadeTransition and a SlideTransition, so a bare `byType` matches Nook's
/// animation and the framework's together.
void main() {
  /// A press target has to paint: `Listener` defers hit testing to its child,
  /// and an empty SizedBox takes no pointers.
  Widget pressTarget() => const SizedBox(
    key: Key('target'),
    width: 100,
    height: 40,
    child: ColoredBox(color: Color(0xFF000000)),
  );

  group('Entrance', () {
    testWidgets('fades its child in, then settles at rest', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Entrance(child: Text('card'))),
      );

      final fade = find.descendant(
        of: find.byType(Entrance),
        matching: find.byType(FadeTransition),
      );
      double opacity() => tester.widget<FadeTransition>(fade).opacity.value;

      expect(opacity(), 0, reason: 'starts invisible');

      await tester.pump(NookMotion.normal ~/ 2);
      expect(opacity(), greaterThan(0));
      expect(opacity(), lessThan(1));

      await tester.pump(NookMotion.normal);
      expect(opacity(), 1, reason: 'settles fully opaque');
      expect(find.text('card'), findsOneWidget);
    });

    testWidgets('lifts its child as it fades', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Entrance(child: Text('card'))),
      );
      final start = tester.getTopLeft(find.text('card'));

      await tester.pump(NookMotion.normal * 2);
      final settled = tester.getTopLeft(find.text('card'));

      expect(start.dy - settled.dy, closeTo(NookMotion.enterOffset, 0.01));
    });

    testWidgets('staggers by index rather than starting everything at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              Entrance(index: 0, child: Text('first')),
              Entrance(index: 4, child: Text('fifth')),
            ],
          ),
        ),
      );

      // ancestor walks nearest-first, so .first is the Entrance's own fade
      // rather than the route's.
      double opacityOf(String text) => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text(text),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;

      await tester.pump(NookMotion.normal ~/ 2);
      expect(opacityOf('first'), greaterThan(0));
      expect(opacityOf('fifth'), 0, reason: 'four beats of delay still to run');

      await tester.pumpAndSettle();
      expect(opacityOf('first'), 1);
      expect(opacityOf('fifth'), 1);
    });

    testWidgets('caps the stagger so a long list still finishes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Entrance(index: 40, maxStaggered: 6, child: Text('last')),
        ),
      );

      // Six beats, not forty: 40 * 45ms would be 1.8s before this even starts.
      await tester.pump(NookMotion.stagger * 6);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.text('last'),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        1,
      );
    });

    testWidgets('disposed mid-stagger leaves no pending timer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Entrance(index: 6, child: Text('late'))),
      );
      // Torn down before its delayed start fires. An uncancelled timer fails
      // this test at teardown with "A Timer is still pending".
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('late'), findsNothing);
    });
  });

  group('PressEffect', () {
    double scaleIn(WidgetTester tester) => tester
        .widget<AnimatedScale>(
          find.descendant(
            of: find.byType(PressEffect),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    testWidgets('scales down while held and returns on release', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: PressEffect(child: pressTarget())),
        ),
      );
      expect(scaleIn(tester), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
      );
      await tester.pump();
      expect(scaleIn(tester), 0.97, reason: 'pressed');

      await gesture.up();
      await tester.pump();
      expect(scaleIn(tester), 1, reason: 'released');
    });

    testWidgets('returns on a cancelled pointer, not just a clean release', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: PressEffect(child: pressTarget())),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
      );
      await tester.pump();
      expect(scaleIn(tester), 0.97);

      await gesture.cancel();
      await tester.pump();
      expect(scaleIn(tester), 1, reason: 'a cancelled press must not stick');
    });

    testWidgets('does not swallow the tap it decorates', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: PressEffect(
                child: InkWell(onTap: () => taps++, child: pressTarget()),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('target')));
      await tester.pump();
      expect(taps, 1, reason: 'Listener must not enter the gesture arena');
    });

    testWidgets('a disabled button does not move', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: PressEffect(enabled: false, child: pressTarget()),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
      );
      await tester.pump();
      expect(scaleIn(tester), 1);
      await gesture.up();
    });
  });

  group('SaveFlight', () {
    /// Puts a real Overlay on screen and hands back its root state.
    Future<OverlayState> host(WidgetTester tester) async {
      late OverlayState overlay;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              overlay = Overlay.of(context, rootOverlay: true);
              return const SizedBox();
            },
          ),
        ),
      );
      return overlay;
    }

    /// Where the flight actually is on screen, and how big. Taken from the laid
    /// out thumbnail rather than the Positioned, which carries only left and
    /// top — the size comes from the box inside it.
    Rect flightIn(WidgetTester tester) =>
        tester.getRect(find.byType(PostThumbnail));

    testWidgets('flies, then removes itself from the overlay', (tester) async {
      final overlay = await host(tester);

      SaveFlight.run(
        overlay,
        from: const Rect.fromLTWH(20, 400, 72, 72),
        thumbnailUrl: null,
      );
      await tester.pump();
      expect(
        find.byType(PostThumbnail),
        findsOneWidget,
        reason: 'the flight is in the air',
      );

      await tester.pump(NookMotion.slow);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.byType(PostThumbnail),
        findsNothing,
        reason: 'the overlay entry removed itself',
      );
    });

    testWidgets('travels towards the Trips tab, shrinking, along an arc', (
      tester,
    ) async {
      final overlay = await host(tester);

      SaveFlight.run(
        overlay,
        from: const Rect.fromLTWH(20, 500, 72, 72),
        thumbnailUrl: null,
      );
      await tester.pump();
      final start = flightIn(tester);

      await tester.pump(NookMotion.slow ~/ 2);
      final mid = flightIn(tester);

      // Trips is tab 1 of 4, so 0.375 of the width — right of a thumbnail on
      // the left edge — and its bar is at the bottom.
      expect(
        mid.center.dx,
        greaterThan(start.center.dx),
        reason: 'moving right towards tab 1 of 4',
      );
      expect(
        mid.center.dy,
        greaterThan(start.center.dy),
        reason: 'moving down towards the bar',
      );
      expect(mid.width, lessThan(start.width), reason: 'shrinking');

      // The arc is the point. Progress is recovered from the width, which is a
      // pure function of it — size == from.width * (1 - 0.72v) — and at that
      // progress the flight sits above the straight chord.
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final v = (1 - mid.width / 72) / 0.72;
      const startCentreY = 500 + 72 / 2;
      final endCentreY = screen.height - 34;
      final chord = startCentreY + (endCentreY - startCentreY) * v;
      expect(
        mid.center.dy,
        lessThan(chord),
        reason: 'lifted above the chord by the arc',
      );

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('keeps a 16:9 box rather than a square', (tester) async {
      final overlay = await host(tester);

      SaveFlight.run(
        overlay,
        from: const Rect.fromLTWH(20, 400, 72, 72),
        thumbnailUrl: null,
      );
      await tester.pump();

      final box = flightIn(tester);
      expect(box.width / box.height, closeTo(16 / 9, 0.01));

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('survives the route it started from being popped', (
      tester,
    ) async {
      final overlay = await host(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const Text('review')),
      );
      await tester.pumpAndSettle();

      SaveFlight.run(
        overlay,
        from: const Rect.fromLTWH(20, 400, 72, 72),
        thumbnailUrl: null,
      );
      navigator.popUntil((route) => route.isFirst);
      await tester.pump();

      expect(
        find.byType(PostThumbnail),
        findsOneWidget,
        reason: 'the root overlay outlives the popped route',
      );

      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PostThumbnail), findsNothing);
    });

    testWidgets('an overlay torn down mid-flight does not throw', (
      tester,
    ) async {
      final overlay = await host(tester);

      SaveFlight.run(
        overlay,
        from: const Rect.fromLTWH(20, 400, 72, 72),
        thumbnailUrl: null,
      );
      await tester.pump(NookMotion.slow ~/ 3);

      // The controller is disposed part-way, which completes its ticker future
      // with TickerCanceled. Unguarded, that removes the entry a second time or
      // surfaces as an unhandled rejection.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('page transitions', () {
    testWidgets('a pushed route slides and fades in', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NookTheme.theme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const Text('next')),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final fade = find
          .ancestor(
            of: find.text('next'),
            matching: find.byType(FadeTransition),
          )
          .first;
      final opacity = tester.widget<FadeTransition>(fade).opacity.value;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1), reason: 'mid-transition, still arriving');

      expect(
        find.ancestor(
          of: find.text('next'),
          matching: find.byType(SlideTransition),
        ),
        findsWidgets,
      );

      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        1,
        reason: 'settles fully opaque',
      );
    });
  });

  group('map pin', () {
    /// The map never settles — tiles retry and the controller animates — so
    /// these pump a bounded number of frames rather than calling pumpAndSettle.
    Future<void> frames(
      WidgetTester tester,
      Duration step, [
      int count = 4,
    ]) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(step);
      }
    }

    testWidgets('drops in and settles at its point', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PostMap(
              latitude: 35.0116,
              longitude: 135.7681,
              label: 'Kyoto',
            ),
          ),
        ),
      );
      await tester.pump();

      final pin = find.byIcon(Icons.location_on);
      expect(pin, findsOneWidget);
      final start = tester.getCenter(pin);

      await frames(tester, NookMotion.slow ~/ 4);
      final settled = tester.getCenter(pin);

      // It begins above its resting place and comes down to it.
      expect(start.dy, lessThan(settled.dy), reason: 'dropped in');

      // Opacity never leaves the legal range, although elasticOut overshoots
      // past 1 — which is why the fade runs off its own curve.
      for (final o in tester.widgetList<Opacity>(
        find.ancestor(of: pin, matching: find.byType(Opacity)),
      )) {
        expect(o.opacity, inInclusiveRange(0.0, 1.0));
      }

      tester.takeException();
    });

    testWidgets('disposes its controller and curves without complaint', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PostMap(latitude: 1, longitude: 1, label: 'x')),
        ),
      );
      await tester.pump(NookMotion.fast);

      // Torn down mid-drop: an undisposed CurvedAnimation leaves a listener on
      // a disposed controller, which asserts on the next tick.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.location_on), findsNothing);
      tester.takeException();
    });
  });

  group('DeleteFlight', () {
    Future<OverlayState> host(WidgetTester tester) async {
      late OverlayState overlay;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              overlay = Overlay.of(context, rootOverlay: true);
              return const SizedBox();
            },
          ),
        ),
      );
      return overlay;
    }

    testWidgets('travels towards Profile, where Recently Deleted lives', (
      tester,
    ) async {
      final overlay = await host(tester);

      DeleteFlight.run(
        overlay,
        from: const Rect.fromLTWH(20, 300, 56, 56),
        thumbnailUrl: null,
      );
      await tester.pump();
      final start = tester.getRect(find.byType(PostThumbnail));

      await tester.pump(NookMotion.slow ~/ 2);
      final mid = tester.getRect(find.byType(PostThumbnail));

      // Profile is tab 3 of 4, at 0.875 of the width — further right than the
      // Trips tab a save flies to, which is the point: the two animations say
      // different things.
      expect(mid.center.dx, greaterThan(start.center.dx));
      expect(mid.width, lessThan(start.width));

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('aims further right than a save does', (tester) async {
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final saveTarget = Flight.tabCentre(
        screen,
        EdgeInsets.zero,
        SaveFlight.tab,
      );
      final deleteTarget = Flight.tabCentre(
        screen,
        EdgeInsets.zero,
        DeleteFlight.tab,
      );

      expect(deleteTarget.dx, greaterThan(saveTarget.dx));
      expect(saveTarget.dy, deleteTarget.dy, reason: 'both land on the bar');
    });

    testWidgets('completes its future so the caller can wait for it', (
      tester,
    ) async {
      final overlay = await host(tester);
      var landed = false;

      DeleteFlight.run(
        overlay,
        from: const Rect.fromLTWH(20, 300, 56, 56),
        thumbnailUrl: null,
      ).then((_) => landed = true);

      await tester.pump();
      expect(landed, isFalse, reason: 'still in the air');

      await tester.pump(NookMotion.slow);
      await tester.pump(const Duration(milliseconds: 60));
      expect(landed, isTrue, reason: 'the delete waits on this');
      expect(find.byType(PostThumbnail), findsNothing);
    });

    testWidgets('an overlay torn down mid-flight does not throw', (
      tester,
    ) async {
      final overlay = await host(tester);

      DeleteFlight.run(
        overlay,
        from: const Rect.fromLTWH(20, 300, 56, 56),
        thumbnailUrl: null,
      );
      await tester.pump(NookMotion.slow ~/ 3);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
