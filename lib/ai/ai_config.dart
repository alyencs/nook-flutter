import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'ai_extractor.dart';
import 'claude_extractor.dart';
import 'claude_itinerary_generator.dart';
import 'itinerary_generator.dart';
import 'sample_extractor.dart';
import 'sample_itinerary_generator.dart';

/// Decides, once at startup, which extractor the app runs on.
///
/// The rule is simply whether a key is present:
///
/// * Running locally with a `.env` that has `ANTHROPIC_API_KEY` → the real
///   model.
/// * The GitHub Pages build, whose `.env` is created from `.env.example` and
///   carries no key → [SampleExtractor], and the UI says so.
///
/// A billable key is never compiled into a public web build. That is not a
/// limitation being worked around; it is the reason this class exists.
abstract final class NookAi {
  static AiExtractor createExtractor() {
    final key = _env('ANTHROPIC_API_KEY');
    if (key == null || key.isEmpty || key.startsWith('put_your')) {
      return const SampleExtractor();
    }
    return ClaudeExtractor(
      apiKey: key,
      // Blank is the normal case: Nook runs on the fast tier and pins the
      // version itself, so a release cannot change how an installed build
      // behaves. CLAUDE_MODEL overrides that when you want a specific answer.
      model: _env('CLAUDE_MODEL'),
      // Optional. Without it a YouTube post reaches the model as a title; with
      // it, the description comes too, which is where the detail lives.
      youTubeApiKey: _env('YOUTUBE_API_KEY'),
      // Optional, and the only way Instagram and Facebook post text can be
      // read at all: their public oEmbed was withdrawn in 2020. Format is
      // `APP_ID|CLIENT_TOKEN` from a Meta app with oEmbed Read.
      facebookToken: _env('FACEBOOK_TOKEN'),
    );
  }

  /// The itinerary planner, chosen by the same rule as the extractor.
  ///
  /// With a key, plans are written by the model from the traveller's own saved
  /// posts. Without one, [SampleItineraryGenerator] arranges those same posts
  /// into days itself — less writing, the same material — and the screen says
  /// which it was.
  static ItineraryGenerator createItineraryGenerator() {
    final key = _env('ANTHROPIC_API_KEY');
    if (key == null || key.isEmpty || key.startsWith('put_your')) {
      return const SampleItineraryGenerator();
    }
    return ClaudeItineraryGenerator(apiKey: key, model: _env('CLAUDE_MODEL'));
  }

  /// Loads `nook.env` if it is there. A missing or empty file is a normal
  /// state, not an error: it is what every deployed build looks like.
  ///
  /// The name has no leading dot on purpose — see the note in pubspec.yaml.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: 'nook.env');
    } catch (_) {
      // No env file in the bundle. The sample extractor takes over.
    }
  }

  static String? _env(String name) {
    try {
      final value = dotenv.env[name]?.trim();
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }
}
