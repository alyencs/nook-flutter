import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/claude_extractor.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/database.dart';

/// The app scope must outlive the rebuilds of everything under it.
///
/// A builder that wraps the app — the one `MaterialApp.builder` takes, or any
/// `LayoutBuilder` — runs again on every resize. When `AppScope` was built in
/// one of those, each call produced a new `ClaudeExtractor`, throwing away the
/// in-flight request map that stops duplicate model calls and the
/// resolved-model cache, and making `AppScope.updateShouldNotify` return true
/// every time so that every dependent in the app rebuilt.
///
/// `main()` therefore builds the scope once, above everything, and these two
/// tests are the before and after of that.
void main() {
  /// A wrapper that reruns its builder when the window changes, which is the
  /// one property of the real wrapper that matters here.
  Widget rebuildsOnResize(WidgetBuilder builder) =>
      MediaQuery.fromView(view: WidgetsBinding.instance.platformDispatcher.views.first,
          child: LayoutBuilder(builder: (context, _) => builder(context)));

  testWidgets('building the scope inside the builder churns the extractor', (
    tester,
  ) async {
    final db = NookDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tab = ValueNotifier<int>(0);
    final seen = <Object>{};
    var builderCalls = 0;

    Widget tree() => rebuildsOnResize((context) {
      builderCalls++;
      final scope = AppScope(
        db: db,
        tab: tab,
        // NookAi.createExtractor() with a key in .env returns a new
        // ClaudeExtractor every call; without one it returns a const
        // SampleExtractor, which would hide the churn. The keyed path is
        // the one the user runs.
        extractor: ClaudeExtractor(apiKey: 'k'),
        child: const SizedBox.shrink(),
      );
      seen.add(scope.extractor);
      return scope;
    });

    await tester.pumpWidget(tree());
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    tester.view.physicalSize = const Size(900, 700);
    await tester.pump();
    addTearDown(tester.view.reset);

    expect(
      builderCalls,
      greaterThan(1),
      reason: 'a wrapper reruns its builder; that is the premise',
    );
    expect(
      seen,
      hasLength(builderCalls),
      reason: 'this is the bug: one extractor per rebuild',
    );
  });

  testWidgets('hoisted above the builder, the scope is built once', (
    tester,
  ) async {
    final db = NookDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tab = ValueNotifier<int>(0);
    var builderCalls = 0;
    final extractor = ClaudeExtractor(apiKey: 'k');

    // The shape main() uses now.
    Widget tree() => AppScope(
      db: db,
      tab: tab,
      extractor: extractor,
      child: rebuildsOnResize((context) {
        builderCalls++;
        return const SizedBox.shrink();
      }),
    );

    await tester.pumpWidget(tree());
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    tester.view.physicalSize = const Size(900, 700);
    await tester.pump();
    addTearDown(tester.view.reset);

    final scopes = tester.widgetList<AppScope>(find.byType(AppScope)).toList();
    expect(builderCalls, greaterThan(1), reason: 'same premise as above');
    expect(scopes, hasLength(1));
    expect(
      scopes.single.extractor,
      same(extractor),
      reason: 'the extractor survives every rebuild above it',
    );
  });
}
