import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/claude_api.dart';
import 'package:nook/ai/claude_extractor.dart';
import 'package:nook/ai/claude_itinerary_generator.dart';

/// The two names the app and its AI service have to agree on.
///
/// The service refuses any request that does not name one of the tasks it
/// offers — that refusal is what stops the endpoint being usable as a general
/// chat API, so it is not negotiable. The cost of that is a contract spread
/// across two languages: a string constant in Dart, and an allowlist in the
/// service's configuration.
///
/// They drifted once. The extractor asked for a tool the service did not
/// offer, so every extraction came back 400 while the itinerary — whose name
/// happened to match — kept working. Nothing failed in either language's own
/// test suite, because each side was internally consistent and neither read
/// the other. This file is the join: it reads the service's configuration as
/// data and checks the Dart constants against it.
void main() {
  /// `ALLOWED_TOOLS = "a,b"` from the deployed configuration.
  Set<String> allowedInWranglerToml() {
    final file = File('server/wrangler.toml');
    expect(file.existsSync(), isTrue, reason: 'server/wrangler.toml is missing');
    final match = RegExp(
      r'''^\s*ALLOWED_TOOLS\s*=\s*["']([^"']*)["']''',
      multiLine: true,
    ).firstMatch(file.readAsStringSync());
    expect(match, isNotNull, reason: 'ALLOWED_TOOLS is not set in wrangler.toml');
    return match!
        .group(1)!
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  /// The same list again, as the service falls back to when the variable is
  /// unset. Both have to contain the names, since either can be in force.
  Set<String> defaultsInWorkerSource() {
    final file = File('server/src/index.js');
    expect(file.existsSync(), isTrue, reason: 'server/src/index.js is missing');
    final match = RegExp(
      r'tools:\s*\[([^\]]*)\]',
    ).firstMatch(file.readAsStringSync());
    expect(match, isNotNull, reason: 'no default tool list found in the worker');
    return RegExp(r'''['"]([^'"]+)['"]''')
        .allMatches(match!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();
  }

  test('the service offers the tool the extractor asks for', () {
    expect(
      allowedInWranglerToml(),
      contains(ClaudeExtractor.toolName),
      reason:
          'the app would be refused with 400 on every extraction, and the '
          'screen would report it as a service problem',
    );
    expect(defaultsInWorkerSource(), contains(ClaudeExtractor.toolName));
  });

  test('the service offers the tool the planner asks for', () {
    expect(allowedInWranglerToml(), contains(ClaudeItineraryGenerator.toolName));
    expect(defaultsInWorkerSource(), contains(ClaudeItineraryGenerator.toolName));
  });

  test('the two tasks are told apart', () {
    expect(ClaudeExtractor.toolName, isNot(ClaudeItineraryGenerator.toolName));
  });

  test('the service is not asked for more output than it allows', () {
    final toml = File('server/wrangler.toml').readAsStringSync();
    final match = RegExp(
      r'''^\s*MAX_OUTPUT_TOKENS\s*=\s*["']?(\d+)["']?''',
      multiLine: true,
    ).firstMatch(toml);
    expect(match, isNotNull, reason: 'MAX_OUTPUT_TOKENS is not set');

    final ceiling = int.parse(match!.group(1)!);
    for (final asked in [
      ClaudeExtractor.maxOutputTokens,
      ClaudeItineraryGenerator.maxOutputTokens,
    ]) {
      expect(
        asked,
        lessThanOrEqualTo(ceiling),
        reason: 'a request over the ceiling is refused with 400',
      );
    }
  });

  group('a failure is described as the kind of failure it is', () {
    test('a request that never arrived is not called a busy service', () {
      const nothingAnswered = ClaudeApiException(
        message: 'Could not reach the AI service: connection failed',
      );

      expect(nothingAnswered.isUnreachable, isTrue);
      expect(
        nothingAnswered.isTransient,
        isTrue,
        reason: 'still worth retrying — this is only about what is said',
      );
      expect(nothingAnswered.isOverloaded, isFalse);
    });

    test('a service that answered and asked for a moment is busy', () {
      const overloaded = ClaudeApiException(
        status: 529,
        type: 'overloaded_error',
        message: 'overloaded',
      );

      expect(overloaded.isUnreachable, isFalse);
      expect(overloaded.isOverloaded, isTrue);
    });

    test('a refused request is permanent, and is not retried', () {
      const refused = ClaudeApiException(
        status: 400,
        type: 'invalid_request_error',
        message: 'The tool "something_else" is not offered by this service.',
      );

      expect(refused.isTransient, isFalse);
      expect(refused.isUnreachable, isFalse);
      expect(
        refused.isModelUnavailable,
        isFalse,
        reason: 'a refused tool is not a missing model, and must not retire one',
      );
    });
  });
}
