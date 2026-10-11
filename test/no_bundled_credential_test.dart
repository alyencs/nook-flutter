import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/ai_config.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/ai/sample_itinerary_generator.dart';

/// The one thing that must never happen: a key in the published bundle.
///
/// `nook.env` is an asset, so every byte of it is downloadable by anyone who
/// opens the site. The protection is that no credential is read from it — not
/// a rule someone has to remember, but the absence of any code that would.
///
/// An absence is the hardest thing to keep. Nothing fails if a later edit adds
/// `dotenv.env['ANTHROPIC_API_KEY']` back, and nothing in review looks wrong;
/// the key just quietly starts shipping. So the absence is asserted here: this
/// file fills the bundle with credentials and checks they are all ignored.
void main() {
  tearDown(dotenv.clean);

  /// A bundle with every credential-shaped value filled in, as it would look
  /// if someone copied their working file into a build.
  void bundleWithSecrets() {
    dotenv.testLoad(
      fileInput: '''
ANTHROPIC_API_KEY=sk-ant-must-never-be-read-from-here
YOUTUBE_API_KEY=youtube-must-never-be-read-from-here
FACEBOOK_TOKEN=000000|facebook-must-never-be-read-from-here
CLAUDE_MODEL=claude-haiku-4-5-20251001
''',
    );
  }

  test('a key in the bundle does not switch the app onto the real model', () {
    bundleWithSecrets();

    expect(
      NookAi.usesRealModel,
      isFalse,
      reason: 'the only credential this build has is one it must not use',
    );
  });

  test('a key in the bundle does not reach the extractor', () {
    bundleWithSecrets();

    expect(
      NookAi.createExtractor(),
      isA<SampleExtractor>(),
      reason: 'with no service and no define, extraction stays local',
    );
  });

  test('a key in the bundle does not reach the planner', () {
    bundleWithSecrets();

    expect(NookAi.createItineraryGenerator(), isA<SampleItineraryGenerator>());
  });

  test('the settings that are meant to be read still are', () {
    dotenv.testLoad(
      fileInput: 'AI_BACKEND_URL=https://nook-ai.example.workers.dev\n',
    );

    expect(
      NookAi.backendUrl,
      'https://nook-ai.example.workers.dev',
      reason: 'the service address is public and belongs in the bundle',
    );
    expect(
      NookAi.usesRealModel,
      isTrue,
      reason: 'reaching the model through the service needs no credential',
    );
  });

  test('an empty bundle is a normal state, not an error', () {
    dotenv.testLoad(fileInput: '');

    expect(NookAi.backendUrl, isNull);
    expect(NookAi.usesRealModel, isFalse);
    expect(NookAi.createExtractor(), isA<SampleExtractor>());
  });

  test('no credential name is read through the settings path at all', () {
    // Belt and braces for the assertions above: the source itself must not
    // mention a credential anywhere near the env lookup. This is the check
    // that catches a new credential being added to the file next year.
    final source = _configSource();
    final lookups = RegExp(r"_env\(\s*'([A-Z_]+)'\s*\)")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();

    expect(
      lookups,
      {'AI_BACKEND_URL', 'CLAUDE_MODEL'},
      reason: 'anything else read from the bundle is published with it',
    );
    expect(
      source,
      isNot(contains("dotenv.env['ANTHROPIC_API_KEY']")),
      reason: 'the key is a --dart-define, never a bundled value',
    );
  });
}

/// The configuration source, read as text so the check is about what the
/// code can do rather than what one run of it happened to do.
String _configSource() => File('lib/ai/ai_config.dart').readAsStringSync();
