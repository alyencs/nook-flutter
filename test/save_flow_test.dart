import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/daos/users_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/widgets/demo_frame.dart';

/// The save flow, in the tree `main()` actually builds.
///
/// The rest of the suite hosts screens under a bare `MaterialApp`. The running
/// app does not: it is `NookApp` under an `AppScope`, with `DemoFrame` between
/// the app and its routes. Anything that depends on the shape of that tree is
/// invisible to a test that leaves it out, so this file puts it back — and
/// runs the flow twice, once at a window narrow enough to go unframed and once
/// wide enough to be framed, because the frame changes the size every screen
/// is laid out against.
void main() {
  late NookDatabase db;

  setUp(() => db = NookDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The same widget `main()` runs, with the same nesting.
  Widget realApp() {
    final tab = ValueNotifier<int>(0);
    return AppScope(
      db: db,
      tab: tab,
      extractor: const SampleExtractor(),
      child: const NookApp(),
    );
  }

  Future<void> pump(WidgetTester tester, {required bool framed}) async {
    // Wide enough for DemoFrame to draw a phone, or narrow enough that it
    // stands aside and the app takes the window.
    final width = framed ? 1440.0 : DemoFrame.phone.width;
    tester.view.physicalSize = Size(width * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(realApp());
    await tester.pumpAndSettle();
    expect(
      find.byType(DemoFrame),
      findsOneWidget,
      reason: 'the frame is in the tree either way; only its output changes',
    );
  }

  /// Paste a link and walk it all the way to a saved post.
  Future<void> walkSaveFlow(WidgetTester tester) async {
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste Link'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'https://www.tiktok.com/@wanderwithmia/video/ramen-bars-in-osaka',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analyze'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Destination & Category'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japan 2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // skip the note
    await tester.pumpAndSettle();

    expect(find.text('Review & Save'), findsOneWidget);
    await tester.tap(find.text('Save Post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  for (final framed in [false, true]) {
    testWidgets('paste to save raises no assertion '
        '(${framed ? 'framed' : 'full width'})', (tester) async {
      await UsersDao(db).saveProfile(name: 'Ali Sampang');
      await pump(tester, framed: framed);
      await walkSaveFlow(tester);

      expect(tester.takeException(), isNull);
      final saved = await tester.runAsync(
        () => PostsDao(db).search('Ramen Bars in Osaka').first,
      );
      expect(saved, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'tearing the tree down must not assert either',
      );
    });
  }
}
