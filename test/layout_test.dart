import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/ai_extractor.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/daos/users_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/add/add_method_screen.dart';
import 'package:nook/screens/add/choose_trip_screen.dart';
import 'package:nook/screens/add/create_note_screen.dart';
import 'package:nook/screens/add/detected_screen.dart';
import 'package:nook/screens/add/paste_link_screen.dart';
import 'package:nook/screens/add/personal_note_screen.dart';
import 'package:nook/screens/add/post_draft.dart';
import 'package:nook/screens/add/review_save_screen.dart';
import 'package:nook/screens/details/manage_post_screen.dart';
import 'package:nook/screens/details/personal_notes_screen.dart';
import 'package:nook/screens/details/post_details_screen.dart';
import 'package:nook/screens/details/travel_details_screen.dart';
import 'package:nook/screens/home/post_list_screen.dart';
import 'package:nook/screens/onboarding/get_started_screen.dart';
import 'package:nook/screens/onboarding/onboarding_screen.dart';
import 'package:nook/screens/onboarding/profile_setup_screen.dart';
import 'package:nook/screens/onboarding/splash_screen.dart';
import 'package:nook/screens/profile/about_screen.dart';
import 'package:nook/screens/profile/account_screen.dart';
import 'package:nook/screens/profile/connected_platforms_screen.dart';
import 'package:nook/screens/profile/help_screen.dart';
import 'package:nook/screens/profile/settings_screen.dart';
import 'package:nook/screens/root_shell.dart';
import 'package:nook/screens/trips/trip_details_screen.dart';
import 'package:nook/theme/nook_theme.dart';

/// Every screen, drawn on a real phone viewport.
///
/// The rest of the suite pumps at 390x1600 so that lazily built content below
/// the fold exists for its finders. That extra height is exactly what hides
/// vertical overflow, and the padding and type passes changed how much of each
/// screen fits. These tests give each screen the 390x844 an iPhone 14 actually
/// has: a RenderFlex that overflows in either direction throws, and the test
/// fails on it.
const phone = Size(390, 844);

Future<void> pumpPhone(WidgetTester tester, NookDatabase db, Widget child) async {
  tester.view.physicalSize = phone * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppScope(
      db: db,
      tab: ValueNotifier(0),
      extractor: const SampleExtractor(),
      child: MaterialApp(theme: NookTheme.theme, home: child),
    ),
  );
  await settle(tester);
  expect(tester.takeException(), isNull);
}

/// Pumps a bounded number of frames instead of `pumpAndSettle`.
///
/// Two screens never reach a quiet frame: the map tile layer keeps an
/// animation running, and a network thumbnail keeps retrying. `pumpAndSettle`
/// waits for a frame that will not come and fails the test ten minutes later
/// for a reason that has nothing to do with layout. Four frames a second apart
/// is enough for the stream builders to deliver and for the first layout pass
/// to run, which is what these tests measure.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await settle(tester);
}

/// The longest strings the sample library can produce, so that a screen is
/// measured at its widest rather than at its most convenient.
PostDraft longestDraft() => PostDraft.fromLink(
      url: 'https://www.tiktok.com/@wanderwithmia/video/7300000000000000000',
      result: const ExtractionResult(
        title: '3-Day Lisbon Itinerary on a Budget, Miradouros Included',
        creator: '@backpackbetter',
        destination: 'Lisbon, Portugal',
        country: 'Portugal',
        category: 'Itinerary',
        summary: 'Three days of viewpoints, pastel de nata and tram 28, with '
            'every stop reachable on foot or by metro.',
        bestTime: 'March to May',
        budgetNote: 'About PHP 4,500 a day including a hostel bed',
        latitude: 38.7223,
        longitude: -9.1393,
        isSample: true,
      ),
    );

void main() {
  late NookDatabase db;
  late int postId;

  // The id is read here rather than inside a test because `testWidgets` runs
  // its body in a fake-async zone: a Drift stream query schedules a timer
  // there, the fake clock only advances when the tester pumps, and awaiting
  // the stream before the first pump therefore never returns.
  setUp(() async {
    db = NookDatabase.forTesting(NativeDatabase.memory());
    postId = (await PostsDao(db).watchAll().first).first.id;
  });
  tearDown(() => db.close());

  final screens = <String, Widget Function()>{
    'Splash (LA1)': () => const SplashScreen(),
    'Get Started': () => const GetStartedScreen(),
    'Onboarding (LA2-LA5)': () => const OnboardingScreen(),
    'Set Up Profile (LO1)': () => const ProfileSetupScreen(),
    'Add Post': () => const AddMethodScreen(),
    'Paste Link': () => const PasteLinkScreen(),
    'Create Note': () => const CreateNoteScreen(),
    'Detected': () => DetectedScreen(draft: longestDraft()),
    'Choose Trip': () => ChooseTripScreen(draft: longestDraft()),
    'Personal Note': () => PersonalNoteScreen(draft: longestDraft()),
    'Review & Save': () => ReviewSaveScreen(draft: longestDraft()),
    'Settings (P3)': () => const SettingsScreen(),
    'Account': () => const AccountScreen(),
    'Connected Platforms': () => const ConnectedPlatformsScreen(),
    'About Nook': () => const AboutScreen(),
    'Help & Support': () => const HelpScreen(),
    'Trip Details': () => const TripDetailsScreen(tripId: 1),
    'Post Details': () => PostDetailsScreen(postId: postId),
    'Travel Details': () => TravelDetailsScreen(postId: postId),
    'Personal Notes': () => PersonalNotesScreen(postId: postId),
    'Manage Post': () => ManagePostScreen(postId: postId),
    'All Saved Posts': () =>
        PostListScreen(title: 'Recent Saves', posts: PostsDao(db).watchAll()),
  };

  screens.forEach((name, build) {
    testWidgets('$name lays out on a 390x844 phone', (tester) async {
      await pumpPhone(tester, db, build());
      await unmount(tester);
    });
  });

  // The four tabs live inside the shell, which owns the bottom bar, so they
  // are pumped through it rather than on their own.
  for (final (index, tab) in ['Home', 'Trips', 'Add', 'Profile'].indexed) {
    testWidgets('$tab tab lays out on a 390x844 phone', (tester) async {
      await UsersDao(db).saveProfile(name: 'Ali Sampang', email: 'a@b.co');
      tester.view.physicalSize = phone * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          db: db,
          tab: ValueNotifier(index),
          extractor: const SampleExtractor(),
          child: MaterialApp(theme: NookTheme.theme, home: const RootShell()),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
