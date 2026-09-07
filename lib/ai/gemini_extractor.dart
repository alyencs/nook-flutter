import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'ai_extractor.dart';
import 'categories.dart';
import 'thumbnail_from_url.dart';

/// Feature #2, for real.
///
/// One call per saved link, asking for structured JSON so the reply is parsed
/// rather than scraped. The key comes from a git-ignored `.env` and is never
/// compiled into a deployed build — see `docs/06-security-and-privacy.md`.
///
/// A note on what the model is given: a browser cannot fetch a TikTok or
/// Instagram page directly (CORS), so this works from the link itself — its
/// host, its slug, its handle — plus what the model already knows. A URL whose
/// slug reads `5-hidden-cafes-in-kyoto` extracts well; an opaque
/// `/reel/C8xK2p/` may come back with nulls, which is exactly the risk the
/// proposal names and why every field here is optional.
class GeminiExtractor implements AiExtractor {
  GeminiExtractor({required String apiKey, String model = defaultModel})
      : _model = GenerativeModel(
          model: model,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: _responseSchema,
            temperature: 0.2,
          ),
        );

  static const defaultModel = 'gemini-2.5-flash';

  final GenerativeModel _model;

  @override
  bool get isLive => true;

  static final _responseSchema = Schema.object(
    properties: {
      'title': Schema.string(
        description: 'A short human title for the post, from the link slug.',
      ),
      'creator': Schema.string(
        description: 'The @handle if the URL contains one.',
        nullable: true,
      ),
      'destination': Schema.string(
        description: 'The place, as "City, Country". Null if none is evident.',
        nullable: true,
      ),
      'country': Schema.string(description: 'Country alone.', nullable: true),
      'category': Schema.enumString(enumValues: NookCategories.all),
      'summary': Schema.string(
        description: 'Two or three sentences about what a traveller would find.',
        nullable: true,
      ),
      'best_time': Schema.string(
        description: 'Best months to visit, e.g. "March-May".',
        nullable: true,
      ),
      'budget_note': Schema.string(
        description: 'A rough daily budget, e.g. "~EUR80/day excluding flights".',
        nullable: true,
      ),
      'latitude': Schema.number(
        description: 'Latitude of the destination in decimal degrees. Null if '
            'the destination is missing or too broad to place on a map.',
        nullable: true,
      ),
      'longitude': Schema.number(
        description: 'Longitude of the destination in decimal degrees. Null '
            'if the destination is missing or too broad to place on a map.',
        nullable: true,
      ),
    },
    requiredProperties: ['title', 'category'],
  );

  static const _instructions = '''
You extract travel metadata from a social media link for a trip-planning app.

You are given only the URL. Read the host, the path slug and any handle in it,
and combine that with what you already know about the place named. Do not invent
a destination that the link gives you no reason to believe in: returning null is
correct and expected when the link is opaque.

Return JSON only, matching the schema.
- destination: "City, Country" when a specific place is evident, otherwise null.
- category: exactly one of the listed values. Use "Other" when unsure.
- summary: 2-3 sentences, written for a traveller deciding whether to keep this.
- best_time and budget_note: only when the destination is known; otherwise null.
- latitude/longitude: the coordinates of the destination, in decimal degrees,
  so it can be pinned on a map. Give them only for a place specific enough to
  have a single point: a city, a town, an island, a landmark. For a whole
  region or country ("Southeast Asia", "Anywhere") return null for both.
''';

  @override
  Future<ExtractionResult> extract(String url) async {
    late final GenerateContentResponse response;
    try {
      response = await _model.generateContent([
        Content.text('$_instructions\n\nURL: $url'),
      ]);
    } on GenerativeAIException catch (e) {
      throw ExtractionException(_friendly(e.message));
    } catch (_) {
      throw const ExtractionException(
        "Couldn't reach the extraction service. Check your connection.",
      );
    }

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const ExtractionException('The extraction came back empty.');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const ExtractionException(
        "The extraction couldn't be read. Try again, or enter the details yourself.",
      );
    }

    String? string(String key) {
      final value = json[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty || trimmed.toLowerCase() == 'null' ? null : trimmed;
    }

    double? number(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // Coordinates are only useful as a pair, and only inside the real ranges.
    final latitude = number('latitude');
    final longitude = number('longitude');
    final placeable = latitude != null &&
        longitude != null &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180 &&
        !(latitude == 0 && longitude == 0);

    return ExtractionResult(
      title: string('title') ?? _titleFromUrl(url),
      creator: string('creator'),
      destination: string('destination'),
      country: string('country'),
      category: NookCategories.normalise(string('category')),
      summary: string('summary'),
      bestTime: string('best_time'),
      budgetNote: string('budget_note'),
      latitude: placeable ? latitude : null,
      longitude: placeable ? longitude : null,
      // Worked out from the link itself rather than asked of the model: a
      // language model cannot know a thumbnail URL, and would invent one.
      thumbnailUrl: await PostThumbnails.resolve(url),
    );
  }

  String _friendly(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('api key') || lower.contains('api_key')) {
      return 'That Gemini API key was rejected. Check GEMINI_API_KEY in your .env.';
    }
    if (lower.contains('quota') || lower.contains('rate')) {
      return 'The Gemini quota for this key is used up. Try again later.';
    }
    return 'Extraction failed: $message';
  }

  /// Last resort so a post is never saved with an empty title.
  static String _titleFromUrl(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const [];
    for (final segment in segments.reversed) {
      if (segment.contains('-')) {
        return segment
            .split('-')
            .where((word) => word.isNotEmpty)
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
      }
    }
    return 'Saved link';
  }
}
