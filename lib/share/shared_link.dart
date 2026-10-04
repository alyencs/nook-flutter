import 'package:flutter/foundation.dart' show kIsWeb;

import 'shared_link_io.dart'
    if (dart.library.js_interop) 'shared_link_web.dart'
    as platform;

/// A link handed to Nook by another app — the second way in, and a shorter one
/// than copy, open, paste, save.
///
/// Only a source of URLs: everything after this point is the same code the
/// Paste Link screen runs, so a shared post and a pasted one go through one
/// pipeline.
abstract final class SharedLink {
  /// The link Nook was opened with, or null for an ordinary launch.
  ///
  /// On the web this reads the Share Target's query parameters, filled in from
  /// `share_target` in `web/manifest.json`. Both `url` and `text` are searched,
  /// because some apps put the link in the text field.
  static String? initial() {
    if (!kIsWeb) return platform.initialSharedLink();
    return platform.initialSharedLink();
  }

  /// Pulls the first http(s) link out of shared text: share sheets rarely hand
  /// over a bare URL, so the link has to be found inside a sentence.
  static String? firstLinkIn(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final match = RegExp(
      r'https?://[^\s<>"]+',
    ).firstMatch(text.replaceAll('\n', ' '));
    if (match == null) return null;
    // Trailing punctuation belongs to the sentence, not the link.
    return match.group(0)!.replaceAll(RegExp(r'[),.\]]+$'), '');
  }

  /// Clears the share parameters from the address bar, so a reload cannot
  /// re-trigger the same save.
  static void consume() => platform.consumeSharedLink();
}
