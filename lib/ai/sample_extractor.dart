import 'ai_extractor.dart';
import 'categories.dart';

/// What runs when there is no Gemini key — which is always true of the
/// deployed build, because a billable key must never ship in a public web app.
///
/// It is deterministic: the same link always produces the same result, so the
/// app can be demonstrated end to end on the live link. It is also honest —
/// [ExtractionResult.isSample] is true, and the Destination & Category screen
/// says so on screen rather than passing this off as a real extraction.
class SampleExtractor implements AiExtractor {
  const SampleExtractor();

  @override
  bool get isLive => false;

  @override
  Future<ExtractionResult> extract(String url) async {
    // The real call takes a moment, so the loading state is worth showing here
    // too rather than snapping instantly to a result.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final trimmed = url.trim();
    if (trimmed.isEmpty || Uri.tryParse(trimmed)?.host.isEmpty != false) {
      throw const ExtractionException(
        "That doesn't look like a link. Paste a post URL to analyse it.",
      );
    }

    // Prefer a fixture whose subject the link actually mentions, so pasting a
    // Kyoto link gets the Kyoto result rather than an arbitrary one.
    final haystack = trimmed.toLowerCase();
    for (final fixture in _fixtures) {
      if (fixture.keywords.any(haystack.contains)) {
        return fixture.toResult();
      }
    }

    // Otherwise pick one deterministically from the URL itself, but keep the
    // title the link actually implies. Showing "5 Hidden Cafes in Kyoto" for a
    // pasted Osaka link would be needlessly confusing; the notice on screen
    // already says the rest is illustrative.
    final index = trimmed.hashCode.abs() % _fixtures.length;
    final fixture = _fixtures[index];
    final slugTitle = _titleFromUrl(trimmed);
    final creator = _handleFromUrl(trimmed);
    final result = fixture.toResult();
    return ExtractionResult(
      title: slugTitle ?? result.title,
      creator: creator ?? result.creator,
      destination: result.destination,
      country: result.country,
      category: result.category,
      summary: result.summary,
      bestTime: result.bestTime,
      budgetNote: result.budgetNote,
      isSample: true,
    );
  }

  /// "…/hidden-ramen-bars-in-osaka" becomes "Hidden Ramen Bars in Osaka".
  static String? _titleFromUrl(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    const small = {'in', 'on', 'a', 'the', 'for', 'to', 'of', 'and', 'at'};
    for (final segment in segments.reversed) {
      if (!segment.contains('-')) continue;
      final words = segment.split('-').where((w) => w.isNotEmpty).toList();
      if (words.length < 2) continue;
      return words
          .asMap()
          .entries
          .map((e) => e.key > 0 && small.contains(e.value.toLowerCase())
              ? e.value.toLowerCase()
              : e.value[0].toUpperCase() + e.value.substring(1))
          .join(' ');
    }
    return null;
  }

  /// Picks the @handle out of a URL when it carries one.
  static String? _handleFromUrl(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    for (final segment in segments) {
      if (segment.startsWith('@') && segment.length > 1) return segment;
    }
    return null;
  }
}

class _Fixture {
  const _Fixture({
    required this.keywords,
    required this.title,
    required this.creator,
    required this.destination,
    required this.country,
    required this.category,
    required this.summary,
    required this.bestTime,
    required this.budgetNote,
  });

  final List<String> keywords;
  final String title;
  final String creator;
  final String destination;
  final String country;
  final String category;
  final String summary;
  final String bestTime;
  final String budgetNote;

  ExtractionResult toResult() => ExtractionResult(
        title: title,
        creator: creator,
        destination: destination,
        country: country,
        category: NookCategories.normalise(category),
        summary: summary,
        bestTime: bestTime,
        budgetNote: budgetNote,
        isSample: true,
      );
}

/// The same fictional library the app seeds itself with, so a link pasted on
/// the live demo lands in a world that already makes sense.
const _fixtures = <_Fixture>[
  _Fixture(
    keywords: ['kyoto', 'japan', 'matcha', 'cafe'],
    title: '5 Hidden Cafes in Kyoto',
    creator: '@wanderwithmia',
    destination: 'Kyoto, Japan',
    country: 'Japan',
    category: 'Food',
    summary:
        "A curated guide to five off-the-beaten-path cafes tucked away in Kyoto's "
        'backstreets — from a century-old kissaten serving hand-dripped coffee to a '
        'hidden matcha bar near Fushimi Inari. Great for slow travel days.',
    bestTime: 'March–May',
    budgetNote: '~¥3,000/day for cafes and transit',
  ),
  _Fixture(
    keywords: ['lisbon', 'portugal', 'itinerary'],
    title: '3-Day Lisbon Itinerary on a Budget',
    creator: '@backpackbetter',
    destination: 'Lisbon, Portugal',
    country: 'Portugal',
    category: 'Itinerary',
    summary:
        'Three days across Alfama, Belém and Bairro Alto without a single paid tour. '
        'Leans on the tram network and free viewpoints, with one splurge meal built in.',
    bestTime: 'March–May',
    budgetNote: '~€70/day excluding flights',
  ),
  _Fixture(
    keywords: ['porto', 'gems'],
    title: 'Hidden Gems in Porto',
    creator: '@travelbound',
    destination: 'Porto, Portugal',
    country: 'Portugal',
    category: 'Scenery',
    summary:
        'The parts of Porto that survive the crowds: a working azulejo workshop, the '
        'quiet side of the Douro, and a rooftop that locals still use. Best walked '
        'rather than planned.',
    bestTime: 'March–May',
    budgetNote: '~€80/day excluding flights',
  ),
  _Fixture(
    keywords: ['palawan', 'beach', 'philippines'],
    title: 'This Beach in Palawan Looks Fake',
    creator: '@islandhopper.ph',
    destination: 'Palawan, Philippines',
    country: 'Philippines',
    category: 'Scenery',
    summary:
        'A limestone-fringed cove reachable only by outrigger, with water clear enough '
        'to read the seabed. Go early: the day-tour boats arrive by eleven.',
    bestTime: 'December–March',
    budgetNote: '~₱2,500/day including boat hire',
  ),
  _Fixture(
    keywords: ['bangkok', 'thailand', 'street food'],
    title: 'Best Street Food in Bangkok',
    creator: '@bitesbytara',
    destination: 'Bangkok, Thailand',
    country: 'Thailand',
    category: 'Food',
    summary:
        'A stall-by-stall route through Yaowarat, ordered so nothing repeats and '
        'nothing closes before you reach it. Cash only, and bring an appetite.',
    bestTime: 'November–February',
    budgetNote: '~฿600/day for food',
  ),
  _Fixture(
    keywords: ['bali', 'batur', 'hike', 'indonesia'],
    title: 'Sunrise Hike at Mount Batur, Bali',
    creator: '@trailandsummit',
    destination: 'Bali, Indonesia',
    country: 'Indonesia',
    category: 'Adventure',
    summary:
        'A two-hour pre-dawn climb to the caldera rim, timed so you reach the top as '
        'the light comes over Abang. Guides are compulsory and worth it.',
    bestTime: 'April–October',
    budgetNote: '~IDR 500,000 including guide',
  ),
  _Fixture(
    keywords: ['hostel', 'southeast asia', 'accommodation'],
    title: 'Top 10 Hostels in Southeast Asia',
    creator: '@budgetroamer',
    destination: 'Southeast Asia',
    country: 'Multiple',
    category: 'Accommodation',
    summary:
        'Ten hostels judged on the things that actually matter after a month on the '
        'road: bed quality, water pressure and whether the common room is bearable.',
    bestTime: 'November–March',
    budgetNote: '~\$15/night for a dorm bed',
  ),
  _Fixture(
    keywords: ['pack', 'carry-on', 'luggage'],
    title: 'How to Pack for 2 Weeks in a Carry-On',
    creator: '@travellight.co',
    destination: 'Anywhere',
    country: 'Multiple',
    category: 'Travel',
    summary:
        'A packing method built around one merino layer and a laundry sink. Comes in '
        'under seven kilos, and survives a climate change mid-trip.',
    bestTime: 'Any time of year',
    budgetNote: 'No cost beyond the bag itself',
  ),
];
