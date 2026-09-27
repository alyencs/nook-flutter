import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/theme/nook_motion.dart';
import 'package:nook/widgets/delete_flight.dart';
import 'package:nook/widgets/folder_motion.dart';
import 'package:nook/widgets/logo_assembly.dart';
import 'package:nook/widgets/post_thumbnail.dart';
import 'package:nook/widgets/tab_pulse.dart';

/// The animations added for the delete/restore/folder/landing work, tested for
/// the two things that actually go wrong with them: they never play at all, or
/// they play so briefly that nothing is communicated.
///
/// Every timing assertion is a range rather than an exact frame. The point is
/// not that a curve has a particular value at 170ms; it is that the motion is
/// still visibly happening at a moment a person is looking at the screen.
void main() {
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

  group('FolderOpen', () {
    /// How far the lid has tipped: the cosine the X rotation writes into the
    /// matrix, which is 1 while the folder is shut.
    ///
    /// Read off the matrix rather than compared against `Matrix4.identity()`,
    /// because the transform always carries the perspective entry — it is what
    /// makes the tip read as a lid instead of a shear, and it is there at rest
    /// too, where it has nothing to act on.
    double lidCos(WidgetTester tester) => _lid(tester).entry(1, 1);

    /// How far the lid has lifted off the card, in logical pixels. Negative up.
    double lidLift(WidgetTester tester) => _lid(tester).entry(1, 3);

    Widget folder(VoidCallback onTap) => MaterialApp(
      home: Center(
        child: FolderOpen(
          onTap: onTap,
          child: const SizedBox(
            width: 120,
            height: 72,
            child: ColoredBox(color: Color(0xFFEEEEEE)),
          ),
        ),
      ),
    );

    testWidgets('sits still until it is tapped', (tester) async {
      await tester.pumpWidget(folder(() {}));
      expect(
        lidCos(tester),
        1.0,
        reason: 'a grid of folders breathing in place is decoration',
      );
      expect(lidLift(tester), 0.0);

      // Still nothing a second later: no idle loop, no repeat.
      await tester.pump(const Duration(seconds: 1));
      expect(lidCos(tester), 1.0);
    });

    testWidgets('tips the lid, and only then opens the trip', (tester) async {
      var opened = 0;
      await tester.pumpWidget(folder(() => opened++));

      await tester.tap(find.byType(FolderOpen));
      await tester.pump();
      await tester.pump(NookMotion.settle ~/ 2);

      expect(
        lidCos(tester),
        lessThan(1.0),
        reason: 'mid-tip, the lid has rotated back',
      );
      expect(
        lidLift(tester),
        lessThan(0.0),
        reason: 'and risen off the card underneath it',
      );
      expect(
        opened,
        0,
        reason: 'the route must not cover the animation it is meant to follow',
      );

      await tester.pump(NookMotion.settle);
      expect(opened, 1, reason: 'opened once the lid is up');

      await tester.pumpAndSettle();
      expect(
        lidCos(tester),
        1.0,
        reason: 'closed again, ready for the next visit',
      );
      expect(lidLift(tester), 0.0);
    });

    testWidgets('one tap is one navigation, however fast the taps', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(folder(() => opened++));

      await tester.tap(find.byType(FolderOpen));
      await tester.pump();
      await tester.tap(find.byType(FolderOpen));
      await tester.pumpAndSettle();

      expect(
        opened,
        1,
        reason: 'a second tap mid-open must not push the screen twice',
      );
    });

    testWidgets('torn down mid-open does not throw', (tester) async {
      await tester.pumpWidget(folder(() {}));
      await tester.tap(find.byType(FolderOpen));
      await tester.pump(NookMotion.settle ~/ 3);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('FolderArrive', () {
    double scaleIn(WidgetTester tester) => tester
        .widget<ScaleTransition>(find.byType(ScaleTransition))
        .scale
        .value;

    testWidgets('springs in from nothing and settles at full size', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: FolderArrive(child: Text('Kyoto'))),
      );

      expect(scaleIn(tester), 0, reason: 'not there yet');

      await tester.pump(NookMotion.settle ~/ 2);
      expect(scaleIn(tester), greaterThan(0));

      await tester.pumpAndSettle();
      expect(scaleIn(tester), 1, reason: 'a card, exactly, once it has landed');
      expect(find.text('Kyoto'), findsOneWidget);
    });

    testWidgets('overshoots, so it reads as a spring and not a fade', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: FolderArrive(child: Text('Kyoto'))),
      );

      var peak = 0.0;
      for (var i = 0; i < 12; i++) {
        await tester.pump(NookMotion.settle ~/ 12);
        peak = peak > scaleIn(tester) ? peak : scaleIn(tester);
      }
      expect(peak, greaterThan(1.0), reason: 'easeOutBack passes 1 and returns');
      await tester.pumpAndSettle();
    });

    testWidgets('does not replay while it stays in the tree', (tester) async {
      const card = MaterialApp(
        home: FolderArrive(key: ValueKey('arrive-1'), child: Text('Kyoto')),
      );
      await tester.pumpWidget(card);
      await tester.pumpAndSettle();
      expect(scaleIn(tester), 1);

      // The trips list is driven by a stream that ticks on every write. A
      // stable key keeps the same State, so a rebuild must not restart it.
      await tester.pumpWidget(card);
      await tester.pump();
      expect(scaleIn(tester), 1, reason: 'no bouncing on every rebuild');
    });
  });

  group('TabPulse', () {
    /// The ring, found by the one thing that makes it a ring.
    Finder ring() => find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration && d.shape == BoxShape.circle;
    });

    testWidgets('expands out of the tab and then clears itself away', (
      tester,
    ) async {
      final overlay = await host(tester);

      TabPulse.at(overlay, const Offset(300, 700));
      await tester.pump();
      expect(ring(), findsOneWidget, reason: 'the tab acknowledges the catch');
      final start = tester.getRect(ring());

      await tester.pump(TabPulse.duration ~/ 2);
      final mid = tester.getRect(ring());
      expect(mid.width, greaterThan(start.width), reason: 'expanding');
      expect(
        mid.center,
        within(distance: 1.0, from: start.center),
        reason: 'centred on the tab throughout',
      );

      await tester.pump(TabPulse.duration);
      await tester.pump(const Duration(milliseconds: 50));
      expect(ring(), findsNothing, reason: 'one pulse, not an indicator');
    });

    testWidgets('fades as it grows, rather than stopping hard', (tester) async {
      final overlay = await host(tester);
      TabPulse.at(overlay, const Offset(300, 700));
      await tester.pump();

      double opacity() => tester
          .widget<Opacity>(
            find.ancestor(of: ring(), matching: find.byType(Opacity)).first,
          )
          .opacity;

      expect(opacity(), 1);
      await tester.pump(TabPulse.duration ~/ 2);
      expect(opacity(), lessThan(1));
      expect(opacity(), greaterThan(0));

      await tester.pump(TabPulse.duration);
    });

    testWidgets('an overlay torn down mid-pulse does not throw', (
      tester,
    ) async {
      final overlay = await host(tester);
      TabPulse.at(overlay, const Offset(300, 700));
      await tester.pump(TabPulse.duration ~/ 3);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('RestoreFlight', () {
    /// The row a restored post is going back to: full width, one line tall.
    const row = Rect.fromLTWH(20, 300, 350, 68);

    Rect flightIn(WidgetTester tester) =>
        tester.getRect(find.byType(PostThumbnail));

    testWidgets('grows out of the tab instead of shrinking into it', (
      tester,
    ) async {
      final overlay = await host(tester);

      RestoreFlight.run(overlay, to: row, thumbnailUrl: null);
      await tester.pump();
      final start = flightIn(tester);

      await tester.pump(NookMotion.deliberate ~/ 2);
      final mid = flightIn(tester);

      expect(
        mid.width,
        greaterThan(start.width),
        reason: 'delete shrinks, restore grows — one interaction, two ways',
      );
      expect(
        mid.center.dy,
        lessThan(start.center.dy),
        reason: 'travelling up the screen, away from the bar',
      );

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('lands on the row rather than covering the list', (
      tester,
    ) async {
      final overlay = await host(tester);

      RestoreFlight.run(overlay, to: row, thumbnailUrl: null);
      await tester.pump();

      // 92% of the way, before the fade-out has taken it far.
      await tester.pump(NookMotion.deliberate * 0.92);
      final late_ = flightIn(tester);

      expect(
        late_.height,
        lessThan(row.height * 1.2),
        reason: 'a card the height of the row it is returning to',
      );
      expect(late_.center.dx, closeTo(row.center.dx, row.width * 0.15));

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('arcs the opposite way to a delete', (tester) async {
      final overlay = await host(tester);

      RestoreFlight.run(overlay, to: row, thumbnailUrl: null);
      await tester.pump();
      final start = flightIn(tester);

      await tester.pump(NookMotion.deliberate ~/ 2);
      final mid = flightIn(tester);

      // Progress is recovered from the width, which is a pure function of it,
      // rather than assumed to be half — the curve is eased, so half the
      // duration is nearly nine tenths of the journey.
      final v = (mid.width / start.width - 1) / (_restoreEndScale - 1);
      final chord = start.center.dy + (row.center.dy - start.center.dy) * v;
      expect(
        mid.center.dy,
        greaterThan(chord),
        reason: 'bent below the chord — the mirror of the delete arc',
      );

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('is watchable, and clears itself away afterwards', (
      tester,
    ) async {
      final overlay = await host(tester);
      var landed = false;

      RestoreFlight.run(
        overlay,
        to: row,
        thumbnailUrl: null,
      ).then((_) => landed = true);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.byType(PostThumbnail),
        findsOneWidget,
        reason: 'still in the air more than half a second in',
      );
      expect(landed, isFalse);

      await tester.pump(NookMotion.deliberate);
      await tester.pump(const Duration(milliseconds: 60));
      expect(landed, isTrue);
      expect(find.byType(PostThumbnail), findsNothing);
    });

    testWidgets('an overlay torn down mid-flight does not throw', (
      tester,
    ) async {
      final overlay = await host(tester);
      RestoreFlight.run(overlay, to: row, thumbnailUrl: null);
      await tester.pump(NookMotion.deliberate ~/ 3);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('LogoAssembly', () {
    testWidgets('spells the name it is assembling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: LogoAssembly())),
      );
      await tester.pumpAndSettle();

      expect(find.text('N'), findsOneWidget);
      expect(find.text('O'), findsNWidgets(2));
      expect(find.text('K'), findsOneWidget);
    });

    testWidgets('arrives a piece at a time, not all at once', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: LogoAssembly())),
      );

      double opacityOf(String glyph) => tester
          .widget<Opacity>(
            find.ancestor(of: find.text(glyph), matching: find.byType(Opacity)),
          )
          .opacity;

      await tester.pump(const Duration(milliseconds: 200));
      expect(opacityOf('N'), greaterThan(0), reason: 'first piece is moving');
      expect(
        opacityOf('K'),
        0,
        reason: 'the last piece has not left yet — that stagger is the effect',
      );

      await tester.pumpAndSettle();
      expect(opacityOf('N'), 1);
      expect(opacityOf('K'), 1);
    });

    testWidgets('each piece travels to its corner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: LogoAssembly())),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final start = tester.getCenter(find.text('N'));

      await tester.pumpAndSettle();
      final settled = tester.getCenter(find.text('N'));

      expect(
        (start - settled).distance,
        greaterThan(60),
        reason: 'a piece that barely moves is a fade wearing a costume',
      );
    });

    testWidgets('tells the screen when the mark is whole', (tester) async {
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: LogoAssembly(onComplete: () => done = true)),
        ),
      );

      await tester.pump(LogoAssembly.duration ~/ 2);
      expect(done, isFalse, reason: 'the wordmark waits for the mark');

      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('torn down mid-assembly does not throw or call back', (
      tester,
    ) async {
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: LogoAssembly(onComplete: () => done = true)),
        ),
      );
      await tester.pump(LogoAssembly.duration ~/ 3);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(done, isFalse, reason: 'no setState on a disposed screen');
    });
  });
}

/// The one Transform a [FolderOpen] builds. Hoisted out of the group so the
/// two readings above can share it.
Matrix4 _lid(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(FolderOpen),
        matching: find.byType(Transform),
      ),
    )
    .transform;

/// What [RestoreFlight] grows to, for a row 68 logical pixels tall: a 16:9
/// card of that height, as a multiple of the 22pt chip it starts as.
const _restoreEndScale = (68 * 16 / 9) / 22;
