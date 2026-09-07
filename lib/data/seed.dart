import 'package:drift/drift.dart';

import '../ai/platform_from_url.dart';
import '../ai/thumbnail_from_url.dart';
import 'database.dart';

/// The demo library, inserted on first run only.
///
/// This is the content drawn across the mockup screens, so the live link opens
/// looking like the design rather than like an empty database. Everything here
/// is invented: the names, the handles and the links are not real accounts or
/// real people, which is what `docs/06-security-and-privacy.md` has to be able
/// to claim about a public repository.
Future<void> seedDatabase(NookDatabase db) async {
  final now = DateTime.now();
  DateTime daysAgo(int days) => now.subtract(Duration(days: days));

  // The row exists so trips have a user to belong to, but it carries no
  // profile: the launch gate treats a nameless row as "not set up yet" and
  // runs the onboarding screens. Set Up Profile fills this same row in.
  final userId = await db.into(db.users).insert(
        UsersCompanion.insert(name: '', email: ''),
      );

  Future<int> trip(String name, int createdDaysAgo) => db.into(db.trips).insert(
        TripsCompanion.insert(
          name: name,
          userId: userId,
          createdAt: daysAgo(createdDaysAgo),
        ),
      );

  // Created oldest first so they list in the order the mockup draws them.
  final japan = await trip('Japan 2027', 90);
  final weekend = await trip('Weekend Getaways', 75);
  final someday = await trip('Someday List', 60);
  final europe = await trip('Europe Backpacking', 45);

  Future<void> post({
    required String title,
    required String creator,
    required String url,
    required int? tripId,
    required String destination,
    required String country,
    required String category,
    required String summary,
    required String bestTime,
    required String budgetNote,
    required int savedDaysAgo,
    double? latitude,
    double? longitude,
    String? note,
    int? viewedDaysAgo,
    int? noteEditedDaysAgo,
  }) async {
    await db.into(db.savedPosts).insert(
          SavedPostsCompanion.insert(
            title: title,
            creator: Value(creator),
            platform: NookPlatform.fromUrl(url),
            originalUrl: Value(url),
            importMethod: 'link',
            aiDestination: Value(destination),
            aiCountry: Value(country),
            aiCategory: Value(category),
            aiSummary: Value(summary),
            aiBestTime: Value(bestTime),
            aiBudgetNote: Value(budgetNote),
            aiLatitude: Value(latitude),
            aiLongitude: Value(longitude),
            thumbnailUrl: Value(PostThumbnails.fromUrl(url)),
            tripId: Value(tripId),
            personalNote: Value(note),
            dateSaved: daysAgo(savedDaysAgo),
            lastViewedAt:
                Value(viewedDaysAgo == null ? null : daysAgo(viewedDaysAgo)),
            noteEditedAt:
                Value(noteEditedDaysAgo == null ? null : daysAgo(noteEditedDaysAgo)),
          ),
        );
  }

  await post(
    title: '5 Hidden Cafes in Kyoto',
    creator: '@wanderwithmia',
    url: 'https://www.tiktok.com/@wanderwithmia/video/5-hidden-cafes-in-kyoto',
    tripId: japan,
    destination: 'Kyoto, Japan',
    country: 'Japan',
    category: 'Food',
    summary:
        "A curated guide to five off-the-beaten-path cafes tucked away in Kyoto's "
        'backstreets — from a century-old kissaten serving hand-dripped coffee to a '
        'hidden matcha bar near Fushimi Inari. Great for slow travel days.',
    bestTime: 'March–May',
    budgetNote: '~¥3,000/day for cafes and transit',
    note:
        'Check if the matcha bar near Fushimi Inari is still open before booking. '
        'Also ask Mia about the one in Gion.',
    savedDaysAgo: 2,
    viewedDaysAgo: 4,
    noteEditedDaysAgo: 1,
    latitude: 35.0116,
    longitude: 135.7681,
  );

  await post(
    title: '3-Day Lisbon Itinerary on a Budget',
    creator: '@backpackbetter',
    url: 'https://www.youtube.com/watch?v=lisbon-3-day-itinerary-budget',
    tripId: europe,
    destination: 'Lisbon, Portugal',
    country: 'Portugal',
    category: 'Itinerary',
    summary:
        'Three days across Alfama, Belém and Bairro Alto without a single paid tour. '
        'Leans on the tram network and free viewpoints, with one splurge meal built in.',
    bestTime: 'March–May',
    budgetNote: '~€70/day excluding flights',
    note: 'The tram 28 tip only works before 9am.',
    savedDaysAgo: 3,
    latitude: 38.7223,
    longitude: -9.1393,
  );

  await post(
    title: 'This Beach in Palawan Looks Fake',
    creator: '@islandhopper.ph',
    url: 'https://www.instagram.com/reel/this-beach-in-palawan-looks-fake',
    tripId: someday,
    destination: 'Palawan, Philippines',
    country: 'Philippines',
    category: 'Scenery',
    summary:
        'A limestone-fringed cove reachable only by outrigger, with water clear enough '
        'to read the seabed. Go early: the day-tour boats arrive by eleven.',
    bestTime: 'December–March',
    budgetNote: '~₱2,500/day including boat hire',
    savedDaysAgo: 6,
    viewedDaysAgo: 1,
    latitude: 9.8349,
    longitude: 118.7384,
  );

  await post(
    title: 'Best Street Food in Bangkok',
    creator: '@bitesbytara',
    url: 'https://www.tiktok.com/@bitesbytara/video/best-street-food-in-bangkok',
    tripId: someday,
    destination: 'Bangkok, Thailand',
    country: 'Thailand',
    category: 'Food',
    summary:
        'A stall-by-stall route through Yaowarat, ordered so nothing repeats and '
        'nothing closes before you reach it. Cash only, and bring an appetite.',
    bestTime: 'November–February',
    budgetNote: '~฿600/day for food',
    savedDaysAgo: 8,
    viewedDaysAgo: 2,
    latitude: 13.7563,
    longitude: 100.5018,
  );

  await post(
    title: 'How to Pack for 2 Weeks in a Carry-On',
    creator: '@travellight.co',
    url: 'https://www.youtube.com/watch?v=pack-2-weeks-carry-on',
    tripId: weekend,
    destination: 'Anywhere',
    country: 'Multiple',
    category: 'Travel',
    summary:
        'A packing method built around one merino layer and a laundry sink. Comes in '
        'under seven kilos, and survives a climate change mid-trip.',
    bestTime: 'Any time of year',
    budgetNote: 'No cost beyond the bag itself',
    savedDaysAgo: 10,
    viewedDaysAgo: 3,
  );

  await post(
    title: 'Sunrise Hike at Mount Batur, Bali',
    creator: '@trailandsummit',
    url: 'https://www.instagram.com/reel/sunrise-hike-mount-batur-bali',
    tripId: someday,
    destination: 'Bali, Indonesia',
    country: 'Indonesia',
    category: 'Adventure',
    summary:
        'A two-hour pre-dawn climb to the caldera rim, timed so you reach the top as '
        'the light comes over Abang. Guides are compulsory and worth it.',
    bestTime: 'April–October',
    budgetNote: '~IDR 500,000 including guide',
    savedDaysAgo: 12,
    viewedDaysAgo: 5,
    latitude: -8.2422,
    longitude: 115.3753,
  );

  await post(
    title: 'Top 10 Hostels in Southeast Asia',
    creator: '@budgetroamer',
    url: 'https://www.tiktok.com/@budgetroamer/video/top-10-hostels-southeast-asia',
    tripId: someday,
    destination: 'Southeast Asia',
    country: 'Multiple',
    category: 'Accommodation',
    summary:
        'Ten hostels judged on the things that actually matter after a month on the '
        'road: bed quality, water pressure and whether the common room is bearable.',
    bestTime: 'November–March',
    budgetNote: '~\$15/night for a dorm bed',
    savedDaysAgo: 14,
    viewedDaysAgo: 6,
  );

  await post(
    title: 'Kyoto Cafe Guide for First-Timers',
    creator: '@wanderwithmia',
    url: 'https://www.tiktok.com/@wanderwithmia/video/kyoto-cafe-guide-first-timers',
    tripId: japan,
    destination: 'Kyoto, Japan',
    country: 'Japan',
    category: 'Food',
    summary:
        'The starter set: four cafes near the main sights that are worth the detour, '
        'with the two that take reservations flagged.',
    bestTime: 'March–May',
    budgetNote: '~¥2,500/day',
    savedDaysAgo: 16,
    latitude: 35.0116,
    longitude: 135.7681,
  );

  await post(
    title: 'Best Matcha Spots Near Fushimi Inari',
    creator: '@matchamaps',
    url: 'https://www.youtube.com/watch?v=best-matcha-fushimi-inari',
    tripId: japan,
    destination: 'Kyoto, Japan',
    country: 'Japan',
    category: 'Food',
    summary:
        'Six matcha stops within walking distance of the shrine gates, ranked by how '
        'far you have to climb to reach them.',
    bestTime: 'March–May',
    budgetNote: '~¥1,800/day',
    savedDaysAgo: 18,
    latitude: 34.9671,
    longitude: 135.7727,
  );

  await post(
    title: 'Hidden Gems in Porto',
    creator: '@travelbound',
    url: 'https://www.instagram.com/reel/hidden-gems-in-porto',
    tripId: europe,
    destination: 'Porto, Portugal',
    country: 'Portugal',
    category: 'Scenery',
    summary:
        'The parts of Porto that survive the crowds: a working azulejo workshop, the '
        'quiet side of the Douro, and a rooftop that locals still use. Best walked '
        'rather than planned.',
    bestTime: 'March–May',
    budgetNote: '~€80/day excluding flights',
    savedDaysAgo: 20,
    viewedDaysAgo: 7,
    latitude: 41.1579,
    longitude: -8.6291,
  );

  await post(
    title: 'Weekend in Baguio Without a Car',
    creator: '@slowtrips.ph',
    url: 'https://www.facebook.com/watch/weekend-in-baguio-without-a-car',
    tripId: weekend,
    destination: 'Baguio, Philippines',
    country: 'Philippines',
    category: 'Itinerary',
    summary:
        'Two days on jeepneys and foot, built around the market and the quieter end '
        'of Burnham Park. Assumes a Friday night bus in.',
    bestTime: 'December–February',
    budgetNote: '~₱1,800/day',
    savedDaysAgo: 24,
    latitude: 16.4023,
    longitude: 120.596,
  );

  await post(
    title: 'Where to Watch the Sunset in Lisbon',
    creator: '@backpackbetter',
    url: 'https://www.youtube.com/watch?v=lisbon-sunset-viewpoints',
    tripId: europe,
    destination: 'Lisbon, Portugal',
    country: 'Portugal',
    category: 'Nightlife',
    summary:
        'Five miradouros ordered by how early you need to arrive to get a spot, and '
        'which ones have a kiosk still serving after dark.',
    bestTime: 'May–September',
    budgetNote: '~€15/evening',
    savedDaysAgo: 28,
    latitude: 38.7223,
    longitude: -9.1393,
  );

  // The searches drawn on the Search screen.
  for (final (index, query) in [
    'Palawan beaches',
    'budget Lisbon itinerary',
    'cafes in Kyoto',
  ].indexed) {
    await db.into(db.recentSearches).insert(
          RecentSearchesCompanion.insert(
            query: query,
            searchedAt: daysAgo(index + 1),
          ),
        );
  }
}
