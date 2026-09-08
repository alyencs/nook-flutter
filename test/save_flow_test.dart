import 'package:device_preview/device_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/daos/users_dao.dart';
import 'package:nook/data/database.dart';

/// The save flow, in the tree `main()` actually builds.
///
/// The rest of the suite hosts screens under a bare `MaterialApp`. The running
/// app does not: `main()` wraps everything in `DevicePreview`, and the crash
/// report came from a browser with the preview panel open. Anything that
/// depends on the shape of the tree above the app is invisible to a test that
/// leaves that wrapper out, so this file puts it back.
void main() {
  late NookDatabase db;

  setUp(() => db = NookDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The same widget `main()` runs, with the same nesting.
  Widget realApp({required bool devicePreview}) {
    final tab = ValueNotifier<int>(0);
    return DevicePreview(
      enabled: devicePreview,
      builder: (context) => AppScope(
        db: db,
        tab: tab,
        extractor: const SampleExtractor(),
        child: const NookApp(),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, {required bool devicePreview}) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(realApp(devicePreview: devicePreview));
    await tester.pumpAndSettle();
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

  for (final withPreview in [false, true]) {
    testWidgets(
      'paste to save raises no assertion '
      '(DevicePreview ${withPreview ? 'on' : 'off'})',
      (tester) async {
        await UsersDao(db).saveProfile(name: 'Ali Sampang', email: 'a@b.co');
        await pump(tester, devicePreview: withPreview);
        await walkSaveFlow(tester);

        expect(tester.takeException(), isNull);
        final saved = await tester.runAsync(
          () => PostsDao(db).search('Ramen Bars in Osaka').first,
        );
        expect(saved, hasLength(1));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'tearing the tree down must not assert either');
      },
    );
  }
}
