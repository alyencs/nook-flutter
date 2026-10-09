import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/daos/users_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/widgets/demo_frame.dart';

/// Nothing in the running app may stand between a finger and a control.
///
/// A widget that quietly takes every pointer looks identical to an app that
/// has crashed: it still paints, still animates, and does nothing when it is
/// touched. On the live link there is no console to tell the two apart, and
/// the usual instinct — reload, clear the site data — changes nothing, because
/// the cause is in the widget tree rather than in the browser.
///
/// Two shapes produce it, and both are checked against the tree the app
/// actually builds: a pointer-absorbing widget laid over the screen, and a
/// second [Navigator] over the first, whose routes are opaque and will consume
/// every hit that reaches them. The behavioural tests then close the loop by
/// driving the tab bar by its coordinates, including across the resizes that
/// are how state of this kind usually gets stuck.
///
/// Note on what is *not* checked: an `IgnorePointer` is not a blocker. Both of
/// its states let the hit continue — `ignoring: true` skips its subtree and
/// the hit falls through to what is behind, `ignoring: false` passes it
/// straight down — and the framework leaves dozens of them in any tree, idle,
/// inside [Overlay], page transitions and every gesture detector. Flagging
/// those says nothing about whether the app can be used.
void main() {
  late NookDatabase db;

  setUp(() async {
    db = NookDatabase.forTesting(NativeDatabase.memory());
    // Launch lands on the shell rather than onboarding. Onboarding animates
    // without end, and a tree that never goes idle cannot be settled.
    await UsersDao(db).saveProfile(name: 'Ali Sampang');
  });
  tearDown(() => db.close());

  Widget app() => AppScope(
    db: db,
    tab: ValueNotifier<int>(0),
    extractor: const SampleExtractor(),
    child: const NookApp(),
  );

  /// Bounded, because `pumpAndSettle` waits for an idle frame and the shell
  /// keeps one scheduled.
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await settle(tester);
  }

  /// Takes the tree down and lets its timers land.
  ///
  /// Called at the end of each test rather than in a tear-down: the framework
  /// checks for pending timers as the body returns, and the shell's animations
  /// each leave one. The database is closed afterwards, which a screen still
  /// watching it would never let finish.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Widgets that swallow a pointer rather than passing it on.
  List<Widget> absorbers(WidgetTester tester) => tester.allWidgets
      .where((w) => w is AbsorbPointer && w.absorbing)
      .toList();

  for (final size in const [
    Size(1440, 900), // a desktop browser, framed
    Size(1024, 768), // a small laptop window, framed
    Size(390, 844), // a phone, unframed
  ]) {
    final name = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('nothing absorbs pointers at $name', (tester) async {
      await pump(tester, size);

      expect(
        absorbers(tester),
        isEmpty,
        reason: 'something over the app is swallowing every pointer',
      );
      await unmount(tester);
    });

    testWidgets('exactly one Navigator at $name', (tester) async {
      await pump(tester, size);

      expect(
        find.byType(Navigator),
        findsOneWidget,
        reason: 'a second Navigator over the app swallows every tap',
      );
      await unmount(tester);
    });

    testWidgets('the tab bar answers a tap at $name', (tester) async {
      await pump(tester, size);

      // By location, not by finder: a widget can be found and still be
      // unreachable, and unreachable is the whole of what is being tested.
      await tester.tapAt(tester.getCenter(find.text('Trips').first));
      await settle(tester);

      expect(find.text('Your Trips'), findsWidgets);
      await unmount(tester);
    });
  }

  testWidgets('the tab bar keeps answering across resizes', (tester) async {
    await pump(tester, const Size(1440, 900));

    // Over the frame's threshold and back, repeatedly. The frame changes shape
    // here, and a wrapper that wedges itself does it on a resize.
    const sizes = [
      Size(DemoFrame.minimumFramedWidth - 1, 900), // unframed, by one pixel
      Size(1920, 1080),
      Size(390, 844),
      Size(DemoFrame.minimumFramedWidth, 900), // framed, by one pixel
      Size(600, 480),
      Size(1440, 900),
    ];

    var onTrips = false;
    for (final size in sizes) {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      await settle(tester);

      expect(
        absorbers(tester),
        isEmpty,
        reason: 'a resize to $size left something absorbing pointers',
      );

      // Alternate, so the tab asked for is never the one already showing and
      // a dead tap cannot pass for a satisfied one.
      onTrips = !onTrips;
      final target = onTrips ? 'Trips' : 'Home';
      await tester.tapAt(tester.getCenter(find.text(target).first));
      await settle(tester);

      expect(
        find.text(onTrips ? 'Your Trips' : 'Recent Saves'),
        findsWidgets,
        reason: 'the tap did not reach the tab bar at $size',
      );
    }
    await unmount(tester);
  });
}
