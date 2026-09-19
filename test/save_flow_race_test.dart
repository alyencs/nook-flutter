import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/ai_extractor.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/daos/users_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/root_shell.dart';
import 'package:nook/theme/nook_theme.dart';

/// The paste-to-save flow under every interleaving a person can actually cause.
///
/// The crash reported was `_dependents.isEmpty is not true` — an
/// `InheritedElement` deactivating while something still depends on it. That
/// only shows up when the tree changes *while* an extraction is in flight, so
/// these tests hold the extraction open and move the tree underneath it: leave
/// the screen, switch tabs, cancel, retry, tap twice. `SampleExtractor` cannot
/// express any of that — it resolves immediately.
class _HeldExtractor implements AiExtractor {
  final _completers = <Completer<ExtractionResult>>[];
  final stages = <String>[];
  int calls = 0;

  @override
  bool get isLive => true;

  @override
  Future<ExtractionResult> extract(String url, {ExtractionStage? onStage}) {
    calls++;
    onStage?.call('Reading the link');
    stages.add('start:$url');
    final completer = Completer<ExtractionResult>();
    _completers.add(completer);
    return completer.future;
  }

  /// Finish the oldest outstanding call.
  void complete({String title = 'Ramen Bars in Osaka'}) {
    final completer = _completers.removeAt(0);
    if (!completer.isCompleted) {
      completer.complete(ExtractionResult(
        title: title,
        creator: '@wanderwithmia',
        destination: 'Osaka, Japan',
        country: 'Japan',
        category: 'Food',
        summary: 'Counters open past midnight.',
        latitude: 34.6937,
        longitude: 135.5023,
      ));
    }
  }

  void fail([String message = 'Gemini is overloaded (HTTP 503).']) {
    final completer = _completers.removeAt(0);
    if (!completer.isCompleted) {
      completer.completeError(ExtractionException(message));
    }
  }

  bool get isBusy => _completers.any((c) => !c.isCompleted);
}

void main() {
  late NookDatabase db;
  late _HeldExtractor extractor;

  setUp(() {
    db = NookDatabase.forTesting(NativeDatabase.memory());
    extractor = _HeldExtractor();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await UsersDao(db).saveProfile(name: 'Ali Sampang', email: 'a@b.co');
    await tester.pumpWidget(
      AppScope(
        db: db,
        tab: ValueNotifier(0),
        extractor: extractor,
        child: MaterialApp(theme: NookTheme.theme, home: const RootShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Add -> Paste Link, with the URL typed in and Analyze tapped.
  Future<void> startAnalysing(WidgetTester tester) async {
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
    await tester.pump();
  }

  /// Everything after the detected screen, through to a saved row.
  Future<void> finishSave(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japan 2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // skip the note
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('the happy path saves exactly one post', (tester) async {
    await pump(tester);
    await startAnalysing(tester);
    extractor.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destination & Category'), findsOneWidget);

    await finishSave(tester);
    expect(tester.takeException(), isNull);

    final saved = await tester.runAsync(
      () => PostsDao(db).search('Ramen Bars in Osaka').first,
    );
    expect(saved, hasLength(1));
    await unmount(tester);
  });

  testWidgets('leaving Paste Link mid-analysis, then the result arriving',
      (tester) async {
    await pump(tester);
    await startAnalysing(tester);

    // Back out while the extraction is still open.
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    extractor.complete();
    await tester.pumpAndSettle();

    // No navigation onto a dead screen, and no assertion.
    expect(find.text('Destination & Category'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('backing out to the shell mid-analysis, then the result arriving',
      (tester) async {
    await pump(tester);
    await startAnalysing(tester);

    // Paste Link is a pushed route, so the tab bar is not on screen: getting
    // back to the shell means popping, twice.
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Trips'), findsWidgets, reason: 'back on the shell');

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();

    extractor.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('cancelling mid-analysis, then analysing again', (tester) async {
    await pump(tester);
    await startAnalysing(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Analyze'), findsOneWidget);

    // The abandoned call lands: it must not push anything.
    extractor.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destination & Category'), findsNothing);

    await tester.tap(find.text('Analyze'));
    await tester.pump();
    extractor.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destination & Category'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a failure, then a retry that succeeds', (tester) async {
    await pump(tester);
    await startAnalysing(tester);

    extractor.fail();
    await tester.pumpAndSettle();
    expect(find.textContaining('overloaded'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    extractor.complete();
    await tester.pumpAndSettle();

    expect(find.text('Destination & Category'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('tapping Analyze twice runs one extraction, not two',
      (tester) async {
    await pump(tester);
    await startAnalysing(tester);

    // The button disables while busy, so press Enter in the field instead —
    // that is the second way into _analyze.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(extractor.calls, 1);

    extractor.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('tapping Save Post twice saves one post', (tester) async {
    await pump(tester);
    await startAnalysing(tester);
    extractor.complete();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japan 2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Post'));
    await tester.pump();
    // Second tap in the same beat, before the insert has come back.
    final second = find.text('Save Post');
    if (second.evaluate().isNotEmpty) {
      await tester.tap(second, warnIfMissed: false);
    }
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(
      () => PostsDao(db).search('Ramen Bars in Osaka').first,
    );
    expect(saved, hasLength(1), reason: 'a double tap must not save twice');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('walking back out of every step of the flow', (tester) async {
    await pump(tester);
    await startAnalysing(tester);
    extractor.complete();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japan 2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Review & Save'), findsOneWidget);

    // All the way back to Home, one screen at a time.
    for (var i = 0; i < 5; i++) {
      final back = find.byIcon(Icons.chevron_left_rounded);
      if (back.evaluate().isEmpty) break;
      await tester.tap(back.first);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the tree is torn down while an extraction is still open',
      (tester) async {
    await pump(tester);
    await startAnalysing(tester);
    expect(extractor.isBusy, isTrue);

    // The whole app goes away mid-flight, then the call lands.
    await unmount(tester);
    extractor.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
