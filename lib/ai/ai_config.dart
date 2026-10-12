import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'ai_extractor.dart';
import 'claude_extractor.dart';
import 'claude_itinerary_generator.dart';
import 'itinerary_generator.dart';
import 'sample_extractor.dart';
import 'sample_itinerary_generator.dart';

/// Decides, once at startup, how the app reaches the model — if at all.
///
/// Three ways, in this order:
///
/// 1. **A backend URL is configured** → the real model, reached through
///    Nook's own service, which holds the key. The app sends no credential.
///    This is what a deployed build uses.
/// 2. **A key is in the env file** → the real model, called directly. For
///    working locally, where the key sits in a git-ignored file on one
///    machine. A build made this way must not be published.
/// 3. **Neither** → [SampleExtractor], and the UI says so.
///
/// Where each setting is allowed to come from matters as much as its value.
///
/// `nook.env` is an **asset**: whatever is in it is compiled into the build
/// and served to anyone who opens the page. So it holds the public settings
/// only — which service to call, which model to ask for. No credential is
/// ever read from it, and [_env] is not reachable from any of them.
///
/// Credentials come from `--dart-define` instead, which is a property of one
/// command on one machine. Passing one is how a local build calls the model
/// directly; the deploy workflow passes none, so there is nothing for a
/// published build to leak. That is a structural guarantee rather than a rule
/// to remember: a key cannot reach the bundle through a path that does not
/// exist.
abstract final class NookAi {
  /// Set at build time with
  /// `--dart-define=NOOK_AI_BACKEND=https://your-service.example.com`,
  /// or by `AI_BACKEND_URL` in the env file when running locally.
  static const _backendDefine = String.fromEnvironment('NOOK_AI_BACKEND');

  /// Credentials, and the only way any of them can be supplied.
  ///
  /// `--dart-define=ANTHROPIC_API_KEY=...` on a local run. Never set by the
  /// deploy workflow, which is what keeps them out of the published build.
  static const _keyDefine = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const _youTubeDefine = String.fromEnvironment('YOUTUBE_API_KEY');
  static const _facebookDefine = String.fromEnvironment('FACEBOOK_TOKEN');

  static String? _define(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.startsWith('put_your')) return null;
    return trimmed;
  }

  /// Where the service is, or null to reach the model directly.
  static String? get backendUrl {
    final defined = _backendDefine.trim();
    if (defined.isNotEmpty) return defined;
    return _env('AI_BACKEND_URL');
  }

  /// The key, only when it is meant to be used from here.
  ///
  /// Ignored entirely when a backend is configured: a build that can reach
  /// the service has no business also carrying a key, and the only way to
  /// publish one by accident is to let both paths be live at once.
  static String? get _directKey {
    if (backendUrl != null) return null;
    return _define(_keyDefine);
  }

  /// Which of the three ways this build is running, for the screens that say
  /// so rather than leaving the traveller to guess.
  static bool get usesRealModel => backendUrl != null || _directKey != null;

  static AiExtractor createExtractor() {
    final backend = backendUrl;
    if (backend != null) {
      return ClaudeExtractor(
        backendUrl: backend,
        // The model is the service's to choose, so that it can be changed
        // without rebuilding and republishing the app.
        model: _env('CLAUDE_MODEL'),
        // Optional. Without it a YouTube post reaches the model as a title;
        // with it, the description comes too, which is where the detail lives.
        youTubeApiKey: _define(_youTubeDefine),
        // Optional now rather than the only route. Meta withdrew public
        // oEmbed in 2020, and this token was the app's one way in — which no
        // deployed build ever had, because the workflow passes no credentials.
        // The service reads the post's public Open Graph tags server-side
        // instead, so a token only adds Meta's own richer oEmbed on top.
        facebookToken: _define(_facebookDefine),
      );
    }

    final key = _directKey;
    if (key == null) return const SampleExtractor();
    return ClaudeExtractor(
      apiKey: key,
      // Blank is the normal case: Nook runs on the fast tier and pins the
      // version itself, so a release cannot change how an installed build
      // behaves. CLAUDE_MODEL overrides that when you want a specific answer.
      model: _env('CLAUDE_MODEL'),
      youTubeApiKey: _define(_youTubeDefine),
      facebookToken: _define(_facebookDefine),
    );
  }

  /// The itinerary planner, chosen by the same rule as the extractor.
  ///
  /// With the model reachable, plans are written from the traveller's own
  /// saved posts. Without it, [SampleItineraryGenerator] arranges those same
  /// posts into days itself — less writing, the same material — and the
  /// screen says which it was.
  static ItineraryGenerator createItineraryGenerator() {
    final backend = backendUrl;
    if (backend != null) {
      return ClaudeItineraryGenerator(
        backendUrl: backend,
        model: _env('CLAUDE_MODEL'),
      );
    }

    final key = _directKey;
    if (key == null) return const SampleItineraryGenerator();
    return ClaudeItineraryGenerator(apiKey: key, model: _env('CLAUDE_MODEL'));
  }

  /// Loads `nook.env` if it is there. A missing or empty file is a normal
  /// state, not an error: it is what a build with no settings looks like.
  ///
  /// The name has no leading dot on purpose — see the note in pubspec.yaml.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: 'nook.env');
    } catch (_) {
      // No env file in the bundle. The sample extractor takes over.
    }
  }

  /// Public settings only. Nothing credential-shaped is read through here,
  /// because everything this reads is served to the browser.
  static String? _env(String name) {
    try {
      final value = dotenv.env[name]?.trim();
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }
}
