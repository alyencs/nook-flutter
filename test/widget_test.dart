import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/app.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/daos/settings_dao.dart';
import 'package:nook/data/daos/users_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/add/create_note_screen.dart';
import 'package:nook/screens/details/travel_details_screen.dart';
import 'package:nook/screens/profile/settings_screen.dart';
import 'package:nook/widgets/post_map.dart';
import 'package:nook/screens/onboarding/splash_screen.dart';
import 'package:nook/screens/root_shell.dart';
import 'package:nook/theme/nook_colors.dart';
import 'package:nook/theme/nook_theme.dart';

/// Wraps a screen in the same scope and theme the real app gives it.
Widget host(NookDatabase db, Widget child) {
  return AppScope(
    db: db,
    tab: ValueNotifier(0),
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

/// Pumps the whole app, launch gate included, rather than one screen.
Future<void> pumpFullApp(WidgetTester tester, NookDatabase db) async {
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppScope(
      db: db,
      tab: ValueNotifier(0),
      extractor: const SampleExtractor(),
      child: const NookApp(),
    ),
  );
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
    // Home is only reached once a profile exists, so give it one.
    await UsersDao(db).saveProfile(name: 'Ali Sampang', email: 'a@b.co');
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

  testWidgets('a fresh install lands on onboarding, not Home', (tester) async {
    // The seed gives trips a user row to belong to, but leaves it nameless, so
    // LA1-LA6 and LO1 are reachable on a first run. Regression guard: when the
    // seed named that row, the launch gate sent every install straight to Home
    // and the onboarding screens could never be seen.
    await pumpFullApp(tester, db);

    expect(find.text('Nook'), findsOneWidget);
    expect(find.text('Never lose your next favourite find.'), findsOneWidget);
    expect(find.text('Recent Saves'), findsNothing);

    await unmount(tester);
  });

  testWidgets('onboarding runs LA1-LA6 through to Set Up Profile',
      (tester) async {
    await pumpFullApp(tester, db);

    await tester.tap(find.text('Continue'));         // LA1 splash
    await tester.pumpAndSettle();
    expect(find.text('Save travel finds'), findsOneWidget);          // LA2

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('AI organizes your trips'), findsOneWidget);    // LA3

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Organize by trip'), findsOneWidget);           // LA4

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Rediscover anything'), findsOneWidget);        // LA5

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Nook'), findsOneWidget);            // LA6

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Set Up Profile'), findsOneWidget);             // LO1
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Profile Picture'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('finishing Set Up Profile opens Home with the seeded library',
      (tester) async {
    await pumpFullApp(tester, db);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Ali Sampang');
    await tester.enterText(find.byType(TextField).at(1), 'ali@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Ali Sampang'), findsOneWidget);
    expect(find.text('Recent Saves'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('Create Note has a note field, and the note is saved',
      (tester) async {
    // The note field used to collapse to nothing — an Expanded inside a Column
    // with unbounded height — so a note could not be typed at all.
    await pumpApp(tester, db, const CreateNoteScreen());

    expect(find.text('Write your thoughts...'), findsOneWidget);
    expect(find.text('0/500'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).at(0), 'Ferry times');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Last boat back is 4pm.',
    );
    await tester.pumpAndSettle();

    expect(find.text('22/500'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Add to trip'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Straight to review: a note already carries its text.
    expect(find.text('Review & Save'), findsOneWidget);
    expect(find.text('Ferry times'), findsOneWidget);
    expect(find.text('Last boat back is 4pm.'), findsOneWidget);

    await tester.tap(find.text('Save Post'));
    await tester.pumpAndSettle();

    // runAsync: reading a real database stream needs real timers, which the
    // fake-async zone a widget test runs in will not fire on its own.
    final saved = await tester.runAsync(
      () => PostsDao(db).search('Ferry times').first,
    );
    expect(saved, hasLength(1));
    expect(saved!.single.personalNote, 'Last boat back is 4pm.');
    expect(saved.single.importMethod, 'note');

    await unmount(tester);
  });

  /// The id of a seeded post, by title.
  Future<int> postId(WidgetTester tester, String title) async {
    final found = await tester.runAsync(() => PostsDao(db).search(title).first);
    return found!.single.id;
  }

  // The map itself is not exercised here on purpose: flutter_map's tile layer
  // keeps live timers for tiles a test environment never serves, so a widget
  // test can neither settle nor tear it down cleanly. The decision either side
  // of it is covered — coordinates in dao_test, the placeholder below — and the
  // rendered map is checked in the browser.

  testWidgets('a post with no coordinates keeps the placeholder, and says why',
      (tester) async {
    // "Southeast Asia" is a region, not a point, so extraction returns no
    // coordinates and the mockup's placeholder stands in.
    final id = await postId(tester, 'Top 10 Hostels in Southeast Asia');
    await pumpApp(tester, db, TravelDetailsScreen(postId: id));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PostMapPlaceholder), findsOneWidget);
    expect(find.byType(PostMap), findsNothing);
    expect(find.textContaining('too broad to place'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('saving a pasted link completes without a framework assertion',
      (tester) async {
    // Regression guard for "_dependents.isEmpty is not true": the save flow
    // used to read ScaffoldMessenger through a context whose element had just
    // been deactivated by popUntil, registering an inherited dependency that
    // could never be cleaned up.
    await UsersDao(db).saveProfile(name: 'Ali Sampang', email: 'a@b.co');
    await pumpApp(tester, db, const RootShell());

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
    // The extractor takes a beat on purpose, so the loading state is real.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Destination & Category'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japan 2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));   // skip the note
    await tester.pumpAndSettle();

    expect(find.text('Review & Save'), findsOneWidget);
    await tester.tap(find.text('Save Post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Back on Home, with the post saved. Any assertion above would already
    // have failed the test.
    expect(tester.takeException(), isNull);
    final saved = await tester.runAsync(
      () => PostsDao(db).search('Ramen Bars in Osaka').first,
    );
    expect(saved, hasLength(1));
    expect(saved!.single.tripId, isNotNull);

    await unmount(tester);
  });

  testWidgets('settings switches persist and drive behaviour', (tester) async {
    await UsersDao(db).saveProfile(name: 'Ali Sampang', email: 'a@b.co');
    await pumpApp(tester, db, const SettingsScreen());

    expect(find.text('Export Data'), findsOneWidget);
    expect(find.text('Clear Search History'), findsOneWidget);
    expect(find.text('Clear Cache'), findsOneWidget);

    // Drawn state: the first three on, the last off.
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.map((s) => s.value).toList(), [true, true, true, false]);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    final stored = await tester.runAsync(() => SettingsDao(db).current());
    expect(stored![NookSettings.saveConfirmation], isTrue);

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
