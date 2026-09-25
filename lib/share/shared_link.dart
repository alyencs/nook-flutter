import 'package:flutter/foundation.dart' show kIsWeb;

import 'shared_link_io.dart'
    if (dart.library.js_interop) 'shared_link_web.dart' as platform;

/// A link handed to Nook by another app.
///
/// The second way in. Copy link → open Nook → paste → save is four steps; this
/// is share → Nook, and the post is already being read by the time the app
/// finishes opening.
///
/// It is deliberately *only* a source of URLs. Everything after this point —
/// platform detection, reading the post, the model call, the save — is the same
/// code the Paste Link screen runs. A shared post and a pasted one are the same
/// post, and there is exactly one pipeline for both.
abstract final class SharedLink {
  /// The link Nook was opened with, or null for an ordinary launch.
  ///
  /// On the web this reads the Share Target's query parameters, which the
  /// browser fills in from `share_target` in `web/manifest.json` when Nook is
  /// installed and the user picks it from a share sheet. Android delivers the
  /// share as a normal navigation, so this works on a cold start.
  ///
  /// The parameters carry a `url`, a `text`, or both — some apps put the link
  /// in the text rather than the url field — so both are searched.
  static String? initial() {
    if (!kIsWeb) return platform.initialSharedLink();
    return platform.initialSharedLink();
  }

  /// Pulls the first http(s) link out of shared text.
  ///
  /// Share sheets rarely hand over a bare URL. TikTok sends
  /// "Check this out! https://vm.tiktok.com/xyz/ …", so the link has to be
  /// found inside the sentence around it.
  static String? firstLinkIn(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final match =
        RegExp(r'https?://[^\s<>"]+').firstMatch(text.replaceAll('\n', ' '));
    if (match == null) return null;
    // Trailing punctuation belongs to the sentence, not the link.
    return match.group(0)!.replaceAll(RegExp(r'[),.\]]+$'), '');
  }

  /// Clears the share parameters from the address bar.
  ///
  /// Without this, a reload would re-trigger the same save, and the URL would
  /// keep someone else's link in it for as long as the tab is open.
  static void consume() => platform.consumeSharedLink();
}
