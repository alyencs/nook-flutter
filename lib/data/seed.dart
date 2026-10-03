import 'package:drift/drift.dart';

import '../ai/platform_from_url.dart';
import '../ai/source_metadata.dart';
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
  final userId = await db
      .into(db.users)
      .insert(UsersCompanion.insert(name: ''));

  Future<int> trip(String name, int createdDaysAgo) => db
      .into(db.trips)
      .insert(
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

    /// The named place the coordinates belong to.
    ///
    /// Without this the specificity gate reads the post as city-level, and the
    /// map chip says "Kyoto" over a pin that is standing on a particular cafe.
    String? placeName,
    String? neighbourhood,

    /// A real photograph of the destination.
    ///
    /// The seeded URLs are invented, so `PostThumbnails.fromUrl` had nothing to
    /// resolve and every demo card drew the empty placeholder.
    String? imageUrl,
    String? note,
    int? viewedDaysAgo,
    int? noteEditedDaysAgo,
  }) async {
    await db
        .into(db.savedPosts)
        .insert(
          SavedPostsCompanion.insert(
            title: title,
            creator: Value(creator),
            platform: NookPlatform.fromUrl(url),
            originalUrl: Value(url),
            importMethod: 'link',
            aiDestination: Value(destination),
            aiCity: Value(
              destination.contains(',')
                  ? destination.split(',').first.trim()
                  : null,
            ),
            aiCountry: Value(country),
            creatorHandle: Value(creator.startsWith('@') ? creator : null),
            sourceId: Value(SourceIds.of(url, NookPlatform.fromUrl(url))),
            mediaType: Value(
              SourceIds.mediaTypeFrom(url, NookPlatform.fromUrl(url)).name,
            ),
            aiCategory: Value(category),
            aiSummary: Value(summary),
            aiBestTime: Value(bestTime),
            aiBudgetNote: Value(budgetNote),
            aiPlaceName: Value(placeName),
            aiNeighbourhood: Value(neighbourhood),
            aiLatitude: Value(latitude),
            aiLongitude: Value(longitude),
            thumbnailUrl: Value(imageUrl ?? PostThumbnails.fromUrl(url)),
            tripId: Value(tripId),
            personalNote: Value(note),
            dateSaved: daysAgo(savedDaysAgo),
            lastViewedAt: Value(
              viewedDaysAgo == null ? null : daysAgo(viewedDaysAgo),
            ),
            noteEditedAt: Value(
              noteEditedDaysAgo == null ? null : daysAgo(noteEditedDaysAgo),
            ),
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
    placeName: 'Nishiki Market',
    neighbourhood: 'Nakagyo',
    latitude: 35.005095,
    longitude: 135.76487,
    imageUrl: 'assets/images/seed_kyoto_cafes.jpg',
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
    placeName: 'Alfama',
    neighbourhood: 'Alfama',
    latitude: 38.7118,
    longitude: -9.1297,
    imageUrl: 'assets/images/seed_lisbon_alfama.jpg',
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
    placeName: 'El Nido',
    neighbourhood: 'Bacuit Bay',
    latitude: 11.1967,
    longitude: 119.4167,
    imageUrl: 'assets/images/seed_palawan.jpg',
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
    imageUrl: 'assets/images/seed_carryon_packing.jpg',
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
    placeName: 'Mount Batur',
    neighbourhood: 'Kintamani',
    latitude: -8.2422,
    longitude: 115.3753,
    imageUrl: 'assets/images/seed_mount_batur.jpg',
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
    placeName: 'Fushimi Inari Taisha',
    neighbourhood: 'Fushimi',
    latitude: 34.9671,
    longitude: 135.7727,
    imageUrl: 'assets/images/seed_fushimi_inari.jpg',
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
    placeName: 'Ribeira',
    neighbourhood: 'Ribeira',
    latitude: 41.1406,
    longitude: -8.611,
    imageUrl: 'assets/images/seed_porto_ribeira.jpg',
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
    placeName: 'Burnham Park',
    neighbourhood: 'Burnham Park',
    latitude: 16.4108,
    longitude: 120.5933,
    imageUrl: 'assets/images/seed_baguio.jpg',
  );

  // The searches drawn on the Search screen.
  for (final (index, query) in [
    'Palawan beaches',
    'budget Lisbon itinerary',
    'cafes in Kyoto',
  ].indexed) {
    await db
        .into(db.recentSearches)
        .insert(
          RecentSearchesCompanion.insert(
            query: query,
            searchedAt: daysAgo(index + 1),
          ),
        );
  }
}
