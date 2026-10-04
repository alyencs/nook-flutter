import 'itinerary.dart';
import 'itinerary_generator.dart';

/// What plans a trip when there is no key — which is every deployed build.
///
/// It is not a stub. The published site has no billable key by design, so this
/// is the itinerary most people will ever see, and a screen of placeholder
/// text would be worse than no feature. So it does the real work the cheap
/// way: it takes the places, tips and notes out of the saved posts, orders
/// them, and spreads them across the days that were asked for.
///
/// What it cannot do is write. A model turns "Nacpan Beach · 40 minutes north"
/// into a sentence about renting a motorbike; this arranges the material and
/// lets it speak for itself. It is deterministic, so the same trip and the
/// same number of days always give the same plan, and
/// [GeneratedItinerary.isSample] is true so the screen says where it came from.
class SampleItineraryGenerator implements ItineraryGenerator {
  const SampleItineraryGenerator();

  /// Matches the live generator, so the chooser offers the same range however
  /// the app is configured.
  static const maxDays = 7;

  @override
  bool get isLive => false;

  @override
  Future<GeneratedItinerary> generate(
    ItineraryRequest request, {
    ItineraryStage? onStage,
  }) async {
    onStage?.call(ItineraryPhase.readingSaves);

    if (!request.hasSources) {
      throw const ItineraryException(
        'There is nothing saved to this trip yet. Save a few posts about the '
        'place first, and Nook can plan around them.',
      );
    }
    if (!request.hasEnoughDetail) {
      throw const ItineraryException(
        'The posts saved here are only titles, so there is not enough to plan '
        'from yet. Open one and add what you know, or save a post with more '
        'detail in it.',
      );
    }

    onStage?.call(ItineraryPhase.planning);
    final candidates = _candidates(request);

    onStage?.call(ItineraryPhase.finishing);
    return GeneratedItinerary(
      destination: request.destination,
      days: _spread(candidates, request),
      isSample: true,
      overview: _overview(request),
      sourceCount: request.sources.length,
    );
  }

  /// One line on what this is and what it was built from.
  String _overview(ItineraryRequest request) {
    final count = request.sources.length;
    final seasons = request.usableSources
        .map((source) => source.bestTime?.trim())
        .whereType<String>()
        .where((season) => season.isNotEmpty)
        .toSet();

    final buffer = StringBuffer()
      ..write('${request.days} ')
      ..write(request.days == 1 ? 'day' : 'days')
      ..write(' in ${request.destination}, built from the $count ')
      ..write(count == 1 ? 'post' : 'posts')
      ..write(' you saved.');

    // Only when the posts agree on one. Two different seasons in one trip is
    // not a recommendation, it is a contradiction, and saying both would be
    // worse than saying neither.
    if (seasons.length == 1) {
      buffer.write(' Your posts put the best time at ${seasons.first}.');
    }
    return buffer.toString();
  }

  /// Everything in the saved posts that could be a thing to do, best first.
  ///
  /// A named venue beats a tip, and a tip beats the post it came from: the more
  /// specific the material, the better a day reads around it.
  List<ItineraryActivity> _candidates(ItineraryRequest request) {
    final seen = <String>{};
    final venues = <ItineraryActivity>[];
    final tips = <ItineraryActivity>[];
    final posts = <ItineraryActivity>[];

    for (final source in request.usableSources) {
      final area = source.neighbourhood ?? source.city;

      for (final place in source.places) {
        if (!seen.add(place.name.toLowerCase())) continue;
        venues.add(
          ItineraryActivity(
            title: place.name,
            description: place.note ?? source.summary ?? source.title,
            location: place.area == null
                ? place.name
                : '${place.name} · ${place.area}',
            timing: null,
          ),
        );
      }

      for (final tip in source.highlights) {
        if (!seen.add(tip.toLowerCase())) continue;
        tips.add(
          ItineraryActivity(
            title: _clause(tip),
            description: tip,
            location: source.placeName ?? area,
          ),
        );
      }

      // A note the traveller wrote outranks everything the platform said, so
      // it earns its own line rather than being folded into a description.
      final note = source.note?.trim();
      if (note != null && note.isNotEmpty && seen.add(note.toLowerCase())) {
        tips.add(
          ItineraryActivity(
            title: 'Your note on ${source.placeName ?? source.title}',
            description: note,
            location: source.placeName ?? area,
          ),
        );
      }

      // The post itself, for anything that named no venue and gave no tips.
      final subject = source.placeName ?? source.title;
      if (source.places.isEmpty && seen.add(subject.toLowerCase())) {
        posts.add(
          ItineraryActivity(
            title: subject,
            // The note is deliberately absent: it has its own entry above,
            // and using it here as well put the same sentence on two days.
            description: source.summary ?? source.caption ?? source.title,
            location: source.placeName == null
                ? area
                : (area == null
                      ? source.placeName
                      : '${source.placeName} · $area'),
          ),
        );
      }
    }

    return [...venues, ...posts, ...tips];
  }

  /// Lays the material out over the days that were asked for.
  ///
  /// Always returns exactly [ItineraryRequest.days] days with at least two
  /// things on each. Where the posts run out, the filler is honest about being
  /// unplanned time rather than inventing a venue nobody saved.
  List<ItineraryDay> _spread(
    List<ItineraryActivity> candidates,
    ItineraryRequest request,
  ) {
    final total = request.days;
    final per = (candidates.length / total).ceil().clamp(1, 4);

    final days = <ItineraryDay>[];
    var next = 0;

    for (var day = 1; day <= total; day++) {
      final activities = <ItineraryActivity>[];

      if (day == 1) {
        activities.add(_arrival(request.destination));
      }

      while (activities.length < per + (day == 1 ? 1 : 0) &&
          next < candidates.length) {
        activities.add(candidates[next++]);
      }

      // The last day keeps a slot back, so a trip ends rather than stopping.
      if (day == total && activities.length < 4) {
        activities.add(_departure(request.destination));
      }

      while (activities.length < 2) {
        activities.add(
          _unplanned(request.destination, day + activities.length),
        );
      }

      days.add(
        ItineraryDay(
          day: day,
          title: _title(day, total, activities),
          activities: List.unmodifiable(activities),
        ),
      );
    }

    // Anything left over goes onto the middle days rather than being dropped:
    // a saved post that never reaches the plan is the one failure this whole
    // feature exists to avoid.
    var cursor = 0;
    while (next < candidates.length) {
      final index = total == 1 ? 0 : 1 + (cursor % (total - 1).clamp(1, total));
      final target = days[index.clamp(0, total - 1)];
      days[index.clamp(0, total - 1)] = ItineraryDay(
        day: target.day,
        title: target.title,
        activities: List.unmodifiable([
          ...target.activities,
          candidates[next++],
        ]),
      );
      cursor++;
    }

    return List.unmodifiable(days);
  }

  ItineraryActivity _arrival(String destination) => ItineraryActivity(
    title: 'Arrive in $destination',
    description:
        'Get in, drop your bags and walk the streets nearest where you are '
        'staying before committing to anything.',
    location: destination,
    timing: 'On arrival',
  );

  ItineraryActivity _departure(String destination) => ItineraryActivity(
    title: 'A slower last morning',
    description:
        'Keep the last morning loose — somewhere to eat nearby, and whichever '
        'of the places you saved you liked enough to repeat.',
    location: destination,
    timing: 'Morning',
  );

  /// Unbooked time, phrased differently each time it is needed.
  ///
  /// Two identical "Rest" rows read as the planner giving up. These are honest
  /// about being unplanned while still suggesting something to do with the
  /// time, and [slot] keeps consecutive days from repeating one another.
  ItineraryActivity _unplanned(String destination, int slot) {
    const options = [
      (
        'Time in',
        'Nothing booked. Walk a neighbourhood you have not seen yet and let '
            'the day go where it goes.',
      ),
      (
        'A slow morning in',
        'No alarm. Breakfast somewhere near where you are staying, then '
            'decide.',
      ),
      (
        'Back to a favourite in',
        'Return to whichever of the places you saved you liked most. The '
            'second visit is usually the better one.',
      ),
      (
        'On foot around',
        'No particular route. The parts of a place you remember are rarely '
            'the ones that were on the list.',
      ),
    ];
    final (prefix, description) = options[slot % options.length];
    return ItineraryActivity(
      title: '$prefix $destination',
      description: description,
      location: destination,
    );
  }

  /// A day's name, taken from what is actually on it.
  String _title(int day, int total, List<ItineraryActivity> activities) {
    if (day == 1) return 'Arrival and first look';
    if (day == total && total > 1) return 'A slower last day';

    final anchor = activities
        .map((activity) => activity.location ?? activity.title)
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    if (anchor.isEmpty) return 'Day $day';

    // "Nacpan Beach · El Nido" reads better as a title without the area.
    final name = anchor.split('·').first.trim();
    return name.isEmpty ? 'Day $day' : '$name and nearby';
  }

  /// The first clause of a tip, for use as its heading.
  static String _clause(String line) {
    final trimmed = line.trim();
    for (final stop in [' — ', ': ', '. ', ', ']) {
      final index = trimmed.indexOf(stop);
      if (index > 8) return trimmed.substring(0, index);
    }
    return trimmed.length <= 60 ? trimmed : '${trimmed.substring(0, 57)}…';
  }
}
