import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/widgets/demo_frame.dart';

/// The frame that holds the app on a desktop browser.
///
/// Its one hard requirement is that it never comes between a finger and a
/// button. The deployed build is where that is hardest to notice and hardest
/// to recover from — there is no console on a live link, and a tap that does
/// nothing looks the same as an app that has crashed — so the pass-through is
/// asserted here rather than left to be found by hand.
void main() {
  /// The app, as far as these tests are concerned: one button at the bottom
  /// of the screen, where Nook puts its primary action.
  Widget appWithButton(VoidCallback onPressed, {Key? key}) => MaterialApp(
    builder: (context, child) => DemoFrame(child: child ?? const SizedBox()),
    home: Scaffold(
      body: Column(
        children: [
          const Spacer(),
          FilledButton(key: key, onPressed: onPressed, child: const Text('Continue')),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );

  Future<void> sized(WidgetTester tester, Size size, Widget app) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  group('when the frame draws', () {
    testWidgets('a wide window gets a phone-sized app', (tester) async {
      await sized(tester, const Size(1440, 900), appWithButton(() {}));

      final frame = tester.getSize(
        find.descendant(
          of: find.byType(DemoFrame),
          matching: find.byType(Scaffold),
        ),
      );
      expect(frame.width, DemoFrame.phone.width);
      expect(frame.height, lessThanOrEqualTo(DemoFrame.phone.height));
    });

    testWidgets('the app inside is told it is phone-sized', (tester) async {
      late Size seen;
      await sized(
        tester,
        const Size(1440, 900),
        MaterialApp(
          builder: (context, child) => DemoFrame(child: child ?? const SizedBox()),
          home: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen.width, DemoFrame.phone.width);
      expect(seen.height, lessThanOrEqualTo(DemoFrame.phone.height));
    });

    testWidgets('a short window gets a shorter phone, not a cropped one', (
      tester,
    ) async {
      await sized(tester, const Size(1440, 600), appWithButton(() {}));

      final frame = tester.getSize(
        find.descendant(
          of: find.byType(DemoFrame),
          matching: find.byType(Scaffold),
        ),
      );
      expect(frame.height, 600 - 2 * DemoFrame.margin);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('when the window is already phone-shaped', () {
    testWidgets('the app is handed the whole window', (tester) async {
      await sized(tester, const Size(390, 844), appWithButton(() {}));

      final frame = tester.getSize(
        find.descendant(
          of: find.byType(DemoFrame),
          matching: find.byType(Scaffold),
        ),
      );
      expect(frame, const Size(390, 844));
    });

    testWidgets('framedAt draws the line at a phone plus its margins', (
      _,
    ) async {
      expect(DemoFrame.framedAt(const Size(390, 844)), isFalse);
      expect(DemoFrame.framedAt(const Size(1440, 400)), isFalse);
      expect(DemoFrame.framedAt(const Size(1440, 900)), isTrue);
      expect(
        DemoFrame.framedAt(const Size(DemoFrame.minimumFramedWidth, 900)),
        isTrue,
      );
    });
  });

  group('nothing between the finger and the button', () {
    for (final size in const [Size(1440, 900), Size(1024, 700), Size(390, 844)]) {
      testWidgets('a tap reaches the app at ${size.width}x${size.height}', (
        tester,
      ) async {
        var taps = 0;
        await sized(tester, size, appWithButton(() => taps++));

        // By location, not by finder: a widget can be present and still be
        // unreachable, and unreachable is the failure being guarded against.
        for (var i = 0; i < 5; i++) {
          await tester.tapAt(tester.getCenter(find.text('Continue')));
          await tester.pumpAndSettle();
        }
        expect(taps, 5, reason: 'every tap landed, not just the first');
      });
    }

    testWidgets('no widget in the frame absorbs or ignores pointers', (
      tester,
    ) async {
      await sized(tester, const Size(1440, 900), appWithButton(() {}));

      final inFrame = find.descendant(
        of: find.byType(DemoFrame),
        matching: find.byType(Widget),
      );
      expect(
        inFrame.evaluate().where(
          (e) => e.widget is AbsorbPointer || e.widget is IgnorePointer,
        ),
        isEmpty,
        reason: 'the frame is scenery; it must not handle pointers at all',
      );
    });

    testWidgets('the app keeps one Navigator, not two', (tester) async {
      await sized(tester, const Size(1440, 900), appWithButton(() {}));

      expect(
        find.byType(Navigator),
        findsOneWidget,
        reason: 'a second Navigator over the app can swallow every tap',
      );
    });
  });
}
