import '../theme/trip_colors.dart';
import 'explore_itinerary.dart';

/// The itineraries Nook ships with.
///
/// Bundled rather than fetched, for the same reason the sample extractor's
/// fixtures are: the published build talks to no server, so content that has
/// to arrive over a network would leave this screen empty on the live link.
/// The destinations are the ones the app already has photographs of, so the
/// catalogue and the seeded library describe one world.

const exploreItineraries = <ExploreItinerary>[
  ExploreItinerary(
    id: 'kyoto-three-days',
    title: 'Three Days in Kyoto',
    destination: 'Kyoto, Japan',
    country: 'Japan',
    days: 3,
    summary:
        'Shrines at first light, backstreet coffee in the afternoon, and the '
        'lanes of Gion once the day trippers have gone. Built to be walked '
        'and ridden rather than driven.',
    bestTime: 'March–May',
    budgetNote: '~¥9,000 for three days, excluding the room',
    colour: TripColor.sand,
    coverImage: 'assets/images/seed_kyoto_cafes.jpg',
    stops: [
      ExploreStop(
        day: 1,
        title: 'Fushimi Inari before the crowds',
        placeName: 'Fushimi Inari Taisha',
        category: 'Scenery',
        summary:
            'The torii tunnel is a different place at seven in the morning. '
            'Climb as far as the Yotsutsuji junction and turn back.',
        area: 'Fushimi',
        image: 'assets/images/seed_fushimi_inari.jpg',
        latitude: 34.9671,
        longitude: 135.7727,
        highlights: [
          'Arrive before 7am and the lower gates are almost empty',
          'The upper loop thins out even at midday',
        ],
      ),
      ExploreStop(
        day: 1,
        title: 'Matcha near the shrine gates',
        placeName: 'Fushimi tea houses',
        category: 'Food',
        summary:
            'A handful of small tea rooms sit between the station and the '
            'first gate. Most close by five.',
        area: 'Fushimi',
        highlights: ['Cash only at the smaller counters'],
      ),
      ExploreStop(
        day: 2,
        title: 'Nishiki Market, end to end',
        placeName: 'Nishiki Market',
        category: 'Food',
        summary:
            'Five covered blocks of knife shops, pickle stalls and standing '
            'counters. Eat as you go rather than looking for a table.',
        area: 'Nakagyo',
        image: 'assets/images/seed_kyoto_cafes.jpg',
        latitude: 35.005095,
        longitude: 135.76487,
        highlights: [
          'Start at the Karasuma end and walk east',
          'Quietest within an hour of opening',
        ],
      ),
      ExploreStop(
        day: 2,
        title: 'An afternoon kissaten',
        placeName: 'Kiyamachi coffee houses',
        category: 'Food',
        summary:
            'Hand-dripped coffee in rooms that have not been redecorated '
            'since the seventies, a few minutes off the market.',
        area: 'Kiyamachi',
      ),
      ExploreStop(
        day: 3,
        title: 'Gion lanes at dusk',
        placeName: 'Gion',
        category: 'Scenery',
        summary:
            'Hanamikoji and the smaller streets behind it, walked slowly in '
            'the last of the light.',
        area: 'Gion',
        latitude: 35.0037,
        longitude: 135.7753,
        highlights: ['Photography is restricted on the private lanes'],
      ),
    ],
  ),
  ExploreItinerary(
    id: 'portugal-by-train',
    title: 'Lisbon and Porto by Train',
    destination: 'Lisbon, Portugal',
    country: 'Portugal',
    days: 5,
    summary:
        'Two cities and the three hours of track between them. Downhill '
        'through Alfama, north on the Alfa Pendular, and a last morning on '
        'the Douro.',
    bestTime: 'March–May',
    budgetNote: '~€75/day excluding flights',
    colour: TripColor.sky,
    coverImage: 'assets/images/seed_lisbon_alfama.jpg',
    stops: [
      ExploreStop(
        day: 1,
        title: 'Alfama, downhill all the way',
        placeName: 'Alfama',
        category: 'Scenery',
        summary:
            'Start at the castle and let the streets take you down to the '
            'river. Nothing here is on a grid.',
        area: 'Alfama',
        image: 'assets/images/seed_lisbon_alfama.jpg',
        latitude: 38.7118,
        longitude: -9.1297,
        highlights: [
          'Tram 28 is bearable before 9am and unbearable after',
          'Wear something with grip — the calçada is slippery wet or dry',
        ],
      ),
      ExploreStop(
        day: 2,
        title: 'Sunset from Senhora do Monte',
        placeName: 'Miradouro da Senhora do Monte',
        category: 'Nightlife',
        summary:
            'The highest of the viewpoints and the last to fill up. The kiosk '
            'stays open after the light goes.',
        area: 'Graça',
        latitude: 38.7172,
        longitude: -9.1322,
        highlights: ['Arrive 45 minutes before sunset for a place on the wall'],
      ),
      ExploreStop(
        day: 3,
        title: 'North on the Alfa Pendular',
        placeName: 'Santa Apolónia to Campanhã',
        category: 'Travel',
        summary:
            'Under three hours, and worth booking a seat on the left for the '
            'coast. Campanhã is two stops from the middle of Porto.',
        highlights: ['Book a few days out — the cheap fares go first'],
      ),
      ExploreStop(
        day: 4,
        title: 'Ribeira and the Douro',
        placeName: 'Ribeira',
        category: 'Scenery',
        summary:
            'The waterfront, the lower deck of the Dom Luís I bridge, and the '
            'quieter Gaia side once you have crossed it.',
        area: 'Ribeira',
        image: 'assets/images/seed_porto_ribeira.jpg',
        latitude: 41.1406,
        longitude: -8.611,
        highlights: ['Cross on the lower deck, come back on the upper'],
      ),
      ExploreStop(
        day: 5,
        title: 'An azulejo workshop morning',
        placeName: 'Porto tile workshops',
        category: 'Other',
        summary:
            'Several working studios take visitors by appointment. A better '
            'last morning than another viewpoint.',
      ),
    ],
  ),
  ExploreItinerary(
    id: 'palawan-island-days',
    title: 'Island Days in Palawan',
    destination: 'El Nido, Philippines',
    country: 'Philippines',
    days: 4,
    summary:
        'Bacuit Bay by outrigger, two lagoons reached before the day boats, '
        'and a long stretch of beach with nothing scheduled on it.',
    bestTime: 'December–March',
    budgetNote: '~₱3,000/day including boat hire',
    colour: TripColor.fern,
    coverImage: 'assets/images/seed_palawan.jpg',
    stops: [
      ExploreStop(
        day: 1,
        title: 'Bacuit Bay by outrigger',
        placeName: 'Bacuit Bay',
        category: 'Scenery',
        summary:
            'Limestone islands an hour off the town beach, reachable only by '
            'boat. Water clear enough to read the seabed.',
        area: 'El Nido',
        image: 'assets/images/seed_palawan.jpg',
        latitude: 11.1967,
        longitude: 119.4167,
        highlights: [
          'Go early — the day-tour fleet arrives by eleven',
          'Agree the route with the boatman before leaving',
        ],
      ),
      ExploreStop(
        day: 2,
        title: 'Big Lagoon at opening time',
        placeName: 'Big Lagoon',
        category: 'Adventure',
        summary:
            'Paddled rather than motored, which is why it stays quiet. The '
            'entrance channel is shallow at low tide.',
        area: 'Miniloc Island',
        highlights: ['Kayak rental is separate from the boat fare'],
      ),
      ExploreStop(
        day: 3,
        title: 'Nacpan Beach, no plans',
        placeName: 'Nacpan Beach',
        category: 'Scenery',
        summary:
            'Four kilometres of sand an hour north of town, with enough room '
            'that the far end is usually empty.',
        highlights: ['Tricycles from town take about 45 minutes'],
      ),
      ExploreStop(
        day: 4,
        title: 'The town market and the pier',
        placeName: 'El Nido town',
        category: 'Food',
        summary:
            'Breakfast at the market, then the pier for whatever came in '
            'overnight. The last morning before the flight back.',
        area: 'El Nido',
      ),
    ],
  ),
  ExploreItinerary(
    id: 'bali-sunrise',
    title: 'Bali: Sunrise and Slow Mornings',
    destination: 'Ubud, Indonesia',
    country: 'Indonesia',
    days: 4,
    summary:
        'One pre-dawn climb, then three days that start late on purpose. '
        'Terraces, a market before the coaches, and warungs away from the '
        'main road.',
    bestTime: 'April–October',
    budgetNote: '~IDR 700,000/day including the guide',
    colour: TripColor.blush,
    coverImage: 'assets/images/seed_mount_batur.jpg',
    stops: [
      ExploreStop(
        day: 1,
        title: 'Mount Batur before dawn',
        placeName: 'Mount Batur',
        category: 'Adventure',
        summary:
            'A two-hour climb to the caldera rim, timed to reach the top as '
            'the light comes over Abang. Guides are compulsory.',
        area: 'Kintamani',
        image: 'assets/images/seed_mount_batur.jpg',
        latitude: -8.2422,
        longitude: 115.3753,
        highlights: [
          'Pick-up is around 2am from Ubud',
          'Take a layer — the rim is cold before sunrise',
        ],
      ),
      ExploreStop(
        day: 2,
        title: 'Terraces at Tegallalang',
        placeName: 'Tegallalang Rice Terraces',
        category: 'Scenery',
        summary:
            'Best walked down one side and up the other rather than viewed '
            'from the road. Small access fees at several points.',
        area: 'Tegallalang',
        highlights: ['Before 9am or after 4pm — the middle of the day is busy'],
      ),
      ExploreStop(
        day: 3,
        title: 'Ubud market, early',
        placeName: 'Ubud Art Market',
        category: 'Food',
        summary:
            'A produce market until about eight, then a souvenir market. Go '
            'for the first version.',
        area: 'Ubud',
      ),
      ExploreStop(
        day: 4,
        title: 'Warungs in Penestanan',
        placeName: 'Penestanan',
        category: 'Food',
        summary:
            'Up the steps west of the river, where the food is cheaper and '
            'the road noise stops.',
        area: 'Penestanan',
      ),
    ],
  ),
  ExploreItinerary(
    id: 'baguio-weekend',
    title: 'A Weekend in Baguio',
    destination: 'Baguio, Philippines',
    country: 'Philippines',
    days: 2,
    summary:
        'Two days on jeepneys and on foot, built around the market and the '
        'quieter end of Burnham Park. Assumes a Friday night bus in.',
    bestTime: 'December–February',
    budgetNote: '~₱1,800/day',
    colour: TripColor.lilac,
    coverImage: 'assets/images/seed_baguio.jpg',
    stops: [
      ExploreStop(
        day: 1,
        title: 'Burnham Park, the quiet end',
        placeName: 'Burnham Park',
        category: 'Scenery',
        summary:
            'The boating lake is the busy part. The pine stands at the far '
            'side are where people actually sit.',
        area: 'Burnham Park',
        image: 'assets/images/seed_baguio.jpg',
        latitude: 16.4108,
        longitude: 120.5933,
        highlights: ['Mornings are cold enough for a jacket year round'],
      ),
      ExploreStop(
        day: 2,
        title: 'The public market, top to bottom',
        placeName: 'Baguio City Market',
        category: 'Food',
        summary:
            'Strawberries, ube, and a dry-goods section that goes on longer '
            'than you expect. Bring small notes.',
        area: 'Central Baguio',
        highlights: ['The vegetable section opens earliest'],
      ),
    ],
  ),
];
