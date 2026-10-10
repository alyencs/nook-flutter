import 'package:device_preview/device_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/daos/users_dao.dart';
import 'package:nook/data/database.dart';

/// Nothing in the running app may stand between a finger and a control.
///
/// A widget that quietly takes every pointer looks identical to an app that
/// has crashed: it still paints, still animates, and does nothing when it is
/// touched. On the live link there is no console to tell the two apart, and
/// the usual instinct — reload, clear the site data — changes nothing, because
/// the cause is in the widget tree rather than in the browser.
///
/// The app runs inside the preview, which draws the device frame and the panel
/// beside it, so that is the tree these tests pump: both of its layouts (the
/// panel on the right above 700pt, the toolbar along the bottom below it), and
/// the resizes across that boundary, which is where state of this kind gets
/// stuck. Each one taps the tab bar *by coordinate* — a widget can be found
/// and still be unreachable, and unreachable is the whole of what is tested.
///
/// Note on what is not checked: an `IgnorePointer` is not a blocker. Both of
/// its states let the hit continue — `ignoring: true` skips its subtree so the
/// hit falls through to what is behind, `ignoring: false` passes it straight
/// down — and the framework leaves dozens of them idle in any tree, inside
/// [Overlay], page transitions and every gesture detector.
void main() {
  late NookDatabase db;

  setUp(() async {
    db = NookDatabase.forTesting(NativeDatabase.memory());
    // Launch lands on the shell rather than onboarding. Onboarding animates
    // without end, and a tree that never goes idle cannot be settled.
    await UsersDao(db).saveProfile(name: 'Ali Sampang');
  });
  tearDown(() => db.close());

  /// The tree `main()` builds, with the preview around it.
  Widget app() => AppScope(
    db: db,
    tab: ValueNotifier<int>(0),
    extractor: const SampleExtractor(),
    child: DevicePreview(
      enabled: true,
      // Nothing written to disk, so one test cannot set the device another
      // test then inherits.
      storage: DevicePreviewStorage.none(),
      builder: (context) => const NookApp(),
    ),
  );

  /// Bounded, because `pumpAndSettle` waits for an idle frame and the shell
  /// keeps one scheduled.
  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
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
    await settle(tester);
  }

  /// Widgets that swallow a pointer rather than passing it on.
  List<Widget> absorbers(WidgetTester tester) =>
      tester.allWidgets.whereType<AbsorbPointer>().where((w) => w.absorbing).toList();

  /// Taps the tab bar and reports whether the tap arrived.
  Future<void> tapTab(WidgetTester tester, String tab, String expected) async {
    // `.last`, because the panel's own labels can repeat the app's and the
    // app is painted after it.
    await tester.tapAt(tester.getCenter(find.text(tab).last));
    await settle(tester);
    expect(find.text(expected), findsWidgets, reason: 'the tap did not arrive');
  }

  group('with the preview panel on the right (wide window)', () {
    const size = Size(1440, 900);

    testWidgets('the panel is there', (tester) async {
      await pump(tester, size);

      expect(
        find.byType(DevicePreview),
        findsOneWidget,
        reason: 'the preview is how the device and its size are chosen',
      );
      await unmount(tester);
    });

    testWidgets('nothing absorbs pointers', (tester) async {
      await pump(tester, size);

      expect(absorbers(tester), isEmpty);
      await unmount(tester);
    });

    testWidgets('the tab bar answers a tap', (tester) async {
      await pump(tester, size);

      await tapTab(tester, 'Trips', 'Your Trips');
      await tapTab(tester, 'Home', 'Recent Saves');
      await unmount(tester);
    });
  });

  group('with the preview toolbar along the bottom (narrow window)', () {
    const size = Size(600, 900);

    testWidgets('nothing absorbs pointers', (tester) async {
      await pump(tester, size);

      expect(absorbers(tester), isEmpty);
      await unmount(tester);
    });

    testWidgets('the tab bar answers a tap', (tester) async {
      await pump(tester, size);

      await tapTab(tester, 'Trips', 'Your Trips');
      await tapTab(tester, 'Home', 'Recent Saves');
      await unmount(tester);
    });
  });

  testWidgets('the tab bar keeps answering across the layout boundary', (
    tester,
  ) async {
    await pump(tester, const Size(1440, 900));

    // Over 700pt and back, repeatedly: that is where the preview swaps its
    // side panel for its bottom toolbar, and where a wrapper that wedges
    // itself does it.
    const sizes = [
      Size(699, 900),
      Size(1920, 1080),
      Size(560, 820),
      Size(701, 900),
      Size(1024, 768),
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
      await tapTab(
        tester,
        onTrips ? 'Trips' : 'Home',
        onTrips ? 'Your Trips' : 'Recent Saves',
      );
    }
    await unmount(tester);
  });
}
