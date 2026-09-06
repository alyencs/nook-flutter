import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/onboarding/splash_screen.dart';
import 'package:nook/screens/root_shell.dart';
import 'package:nook/theme/nook_colors.dart';
import 'package:nook/theme/nook_theme.dart';

/// Wraps a screen in the same scope and theme the real app gives it.
Widget host(NookDatabase db, Widget child) {
  return AppScope(
    db: db,
    extractor: const SampleExtractor(),
    child: MaterialApp(theme: NookTheme.theme, home: child),
  );
}

/// Pumps a screen at phone width and a generous height.
///
/// The default 800x600 test viewport is wider and much shorter than any phone,
/// and lists build lazily: content below the fold is never built, so finders
/// for it fail for reasons that have nothing to do with the code.
Future<void> pumpApp(WidgetTester tester, NookDatabase db, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(db, child));
  await tester.pumpAndSettle();
}

/// Unmounts inside the test.
///
/// Drift schedules a zero-duration timer when a stream query is cancelled. If
/// the tree is still mounted when the test ends, that timer is outstanding at
/// teardown and the framework fails the test for it.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  late NookDatabase db;

  setUp(() {
    db = NookDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  testWidgets('Home shows the greeting, both sections and the tab bar',
      (tester) async {
    await pumpApp(tester, db, const RootShell());

    expect(find.text('Ali Sampang'), findsOneWidget);
    expect(find.text('Recent Saves'), findsOneWidget);
    expect(find.text('Your Trips'), findsOneWidget);
    expect(find.text('5 Hidden Cafes in Kyoto'), findsWidgets);

    // The four tabs, in the order the mockup draws them.
    for (final label in ['Home', 'Trips', 'Add', 'Profile']) {
      expect(find.text(label), findsWidgets, reason: '$label tab missing');
    }
    await unmount(tester);
  });

  testWidgets('tapping the search bar opens search inside the Home tab',
      (tester) async {
    await pumpApp(tester, db, const RootShell());

    await tester.tap(find.text('Search saved posts...'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested Categories'), findsOneWidget);
    expect(find.text('All Saved Posts'), findsOneWidget);
    // The tab bar stays put: the mockup draws it on the search frames, and it
    // is how you get back out.
    expect(find.text('Trips'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('searching filters to matching posts', (tester) async {
    await pumpApp(tester, db, const RootShell());

    await tester.tap(find.text('Search saved posts...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'kyoto');
    await tester.pumpAndSettle();

    expect(find.text('3 results'), findsOneWidget);
    expect(find.text('Best Street Food in Bangkok'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a search with no matches explains itself', (tester) async {
    await pumpApp(tester, db, const RootShell());

    await tester.tap(find.text('Search saved posts...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'reykjavik');
    await tester.pumpAndSettle();

    expect(find.text('No results'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('opening a post shows its details and travel metadata',
      (tester) async {
    await pumpApp(tester, db, const RootShell());

    await tester.tap(find.text('5 Hidden Cafes in Kyoto').first);
    await tester.pumpAndSettle();

    expect(find.text('Post Details'), findsOneWidget);
    expect(find.text('AI SUMMARY'), findsOneWidget);
    expect(find.text('Kyoto, Japan'), findsWidgets);

    await tester.tap(find.text('Travel Details'));
    await tester.pumpAndSettle();

    expect(find.text('Best Time to Visit'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget);
    // The itinerary generator is a stretch goal, and says so rather than
    // pretending to work.
    expect(find.text('Stretch goal — not in this build'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an empty library shows the empty state, not a blank screen',
      (tester) async {
    await db.clearAll();
    await db.into(db.users).insert(
          UsersCompanion.insert(name: 'Ali Sampang', email: 'a@b.co'),
        );

    await pumpApp(tester, db, const RootShell());

    expect(find.text('No trips yet — save your first find'), findsOneWidget);
    expect(find.text('Save First Find'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the splash screen leads into onboarding', (tester) async {
    await pumpApp(tester, db, const SplashScreen());

    expect(find.text('Nook'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Save travel finds'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no Material default colours leak into the theme', (tester) async {
    await pumpApp(tester, db, const RootShell());

    final theme = Theme.of(tester.element(find.byType(RootShell)));
    expect(theme.colorScheme.primary, NookColors.primary);
    expect(theme.textTheme.bodyLarge?.fontFamily, 'Inter');

    await unmount(tester);
  });
}
