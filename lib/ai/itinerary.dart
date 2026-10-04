/// A day-by-day plan, built from what the traveller has already saved.
class GeneratedItinerary {
  const GeneratedItinerary({
    required this.destination,
    required this.days,
    required this.isSample,
    this.overview,
    this.sourceCount = 0,
  });

  final String destination;

  final List<ItineraryDay> days;

  /// True when this came from [SampleItineraryGenerator] rather than a model,
  /// so the screen can say so instead of passing it off as a real generation.
  final bool isSample;

  /// A sentence about the shape of the trip, when the model offered one.
  final String? overview;

  /// How many saved posts went into it, so the screen can show its working.
  final int sourceCount;

  int get dayCount => days.length;

  int get activityCount =>
      days.fold(0, (total, day) => total + day.activities.length);
}

class ItineraryDay {
  const ItineraryDay({
    required this.day,
    required this.title,
    required this.activities,
  });

  final int day;
  final String title;
  final List<ItineraryActivity> activities;
}

class ItineraryActivity {
  const ItineraryActivity({
    required this.title,
    required this.description,
    this.location,
    this.timing,
  });

  final String title;
  final String description;

  /// The place this happens, when the plan names one.
  final String? location;

  /// "9:00 AM – 4:00 PM", "Morning", "After dark". Free text, because the
  /// sources phrase it every way and none of them is a clock.
  final String? timing;
}

/// Turns a decoded model reply into days, or reports why it could not.
///
/// Everything here is defensive. A reply can be well-formed JSON and still be
/// unusable — a day with no activities, a day number the model repeated, a
/// description that runs to three thousand characters — and none of those
/// should reach a screen or a crash.
abstract final class ItineraryParsing {
  /// The longest a single field is allowed to be before it is cut.
  ///
  /// Not a style preference: a model that loses its footing can emit a
  /// paragraph where a title belongs, and a 4,000-character "title" inside a
  /// card is a layout failure rather than content.
  static const maxTitle = 140;
  static const maxDescription = 1200;
  static const maxOverview = 400;

  /// The days from [json], renumbered from one and in order.
  ///
  /// Returns an empty list when there is nothing usable, which the caller
  /// turns into a message rather than an empty screen.
  static List<ItineraryDay> daysFrom(Object? raw) {
    if (raw is! List) return const [];

    final parsed = <ItineraryDay>[];
    for (final entry in raw) {
      if (entry is! Map) continue;

      final activities = _activitiesFrom(entry['activities']);
      // A day with nothing in it is not a day. Dropping it here is what makes
      // the count check below meaningful.
      if (activities.isEmpty) continue;

      parsed.add(
        ItineraryDay(
          day: _intOf(entry['day']) ?? parsed.length + 1,
          title: _string(entry['title'], maxTitle) ?? 'Day ${parsed.length + 1}',
          activities: activities,
        ),
      );
    }

    // The model is asked for them in order and usually obliges, but a day
    // number it repeated or skipped must not become the number on screen.
    parsed.sort((a, b) => a.day.compareTo(b.day));
    return [
      for (var i = 0; i < parsed.length; i++)
        ItineraryDay(
          day: i + 1,
          title: parsed[i].title,
          activities: parsed[i].activities,
        ),
    ];
  }

  static List<ItineraryActivity> _activitiesFrom(Object? raw) {
    if (raw is! List) return const [];

    final activities = <ItineraryActivity>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final title = _string(entry['title'], maxTitle);
      final description = _string(entry['description'], maxDescription);
      // One or the other will do. Both missing means the entry carries
      // nothing, and an empty row is worse than a shorter day.
      if (title == null && description == null) continue;
      activities.add(
        ItineraryActivity(
          title: title ?? description!,
          description: title == null ? '' : (description ?? ''),
          location: _string(entry['location'], maxTitle),
          timing: _string(entry['timing'], maxTitle),
        ),
      );
    }
    return activities;
  }

  static String? overviewFrom(Object? raw) => _string(raw, maxOverview);

  /// Trimmed, with the model's own ways of saying "nothing" treated as null.
  static String? _string(Object? value, int limit) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
    if (trimmed.length <= limit) return trimmed;
    // Cut at a word where there is one close enough to the limit, so the
    // result reads as shortened rather than broken off.
    final cut = trimmed.substring(0, limit);
    final space = cut.lastIndexOf(' ');
    return '${space > limit - 24 ? cut.substring(0, space) : cut}…';
  }

  static int? _intOf(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
