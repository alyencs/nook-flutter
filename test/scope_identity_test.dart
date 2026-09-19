import 'package:device_preview/device_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/gemini_extractor.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/database.dart';

/// The app scope must outlive DevicePreview's rebuilds.
///
/// `DevicePreview` calls its `builder` again on every preview change — four
/// times before the first frame has settled, in this test. When `AppScope` was
/// built in there, each of those calls produced a new `GeminiExtractor`,
/// throwing away the in-flight request map that stops duplicate Gemini calls
/// and the resolved-model cache, and making `AppScope.updateShouldNotify`
/// return true every time so that every dependent in the app rebuilt.
void main() {
  testWidgets('building the scope inside the builder churns the extractor',
      (tester) async {
    final db = NookDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tab = ValueNotifier<int>(0);
    final seen = <Object>{};
    var builderCalls = 0;

    Widget tree() => DevicePreview(
          enabled: true,
          storage: DevicePreviewStorage.none(),
          builder: (context) {
            builderCalls++;
            // Exactly what main() does today.
            final scope = AppScope(
              db: db,
              tab: tab,
              // NookAi.createExtractor() with a key in .env returns a new
              // GeminiExtractor every call; without one it returns a const
              // SampleExtractor, which would hide the churn. The keyed path is
              // the one the user runs.
              extractor: GeminiExtractor(apiKey: 'k'),
              child: const SizedBox.shrink(),
            );
            seen.add(scope.extractor);
            return scope;
          },
        );

    await tester.pumpWidget(tree());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Force more preview rebuilds the way a resize or a panel change would.
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    tester.view.physicalSize = const Size(900, 700);
    await tester.pump();
    addTearDown(tester.view.reset);

    expect(builderCalls, greaterThan(1),
        reason: 'DevicePreview reruns its builder; that is the premise');
    expect(seen, hasLength(builderCalls),
        reason: 'this is the bug: one extractor per rebuild');
  });

  testWidgets('hoisted above DevicePreview, the scope is built once',
      (tester) async {
    final db = NookDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tab = ValueNotifier<int>(0);
    var builderCalls = 0;
    final extractor = GeminiExtractor(apiKey: 'k');

    // The shape main() uses now.
    Widget tree() => AppScope(
          db: db,
          tab: tab,
          extractor: extractor,
          child: DevicePreview(
            enabled: true,
            storage: DevicePreviewStorage.none(),
            builder: (context) {
              builderCalls++;
              return const SizedBox.shrink();
            },
          ),
        );

    await tester.pumpWidget(tree());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    tester.view.physicalSize = const Size(900, 700);
    await tester.pump();
    addTearDown(tester.view.reset);

    final scopes = tester.widgetList<AppScope>(find.byType(AppScope)).toList();
    expect(builderCalls, greaterThan(1), reason: 'same premise as above');
    expect(scopes, hasLength(1));
    expect(scopes.single.extractor, same(extractor),
        reason: 'the extractor survives every preview rebuild');
  });
}
