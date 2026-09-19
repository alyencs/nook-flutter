import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'ai_extractor.dart';
import 'gemini_extractor.dart';
import 'sample_extractor.dart';

/// Decides, once at startup, which extractor the app runs on.
///
/// The rule is simply whether a key is present:
///
/// * Running locally with a `.env` that has `GEMINI_API_KEY` → real Gemini.
/// * The GitHub Pages build, whose `.env` is created from `.env.example` and
///   carries no key → [SampleExtractor], and the UI says so.
///
/// A billable key is never compiled into a public web build. That is not a
/// limitation being worked around; it is the reason this class exists.
abstract final class NookAi {
  static AiExtractor createExtractor() {
    final key = _env('GEMINI_API_KEY');
    if (key == null || key.isEmpty || key.startsWith('put_your')) {
      return const SampleExtractor();
    }
    // No default model id is compiled in on purpose. Google retires them on a
    // schedule — `gemini-2.0-flash` was shut down on 1 June 2026 and took this
    // app's extraction with it — so the extractor asks the API which models the
    // key can reach. GEMINI_MODEL pins one when you want a specific answer.
    return GeminiExtractor(apiKey: key, model: _env('GEMINI_MODEL'));
  }

  /// Loads `.env` if it is there. A missing or empty file is a normal state,
  /// not an error: it is what every deployed build looks like.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // No .env in the bundle. The sample extractor takes over.
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
