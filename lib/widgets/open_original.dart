import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ai/platform_from_url.dart';
import 'nook_toast.dart';

/// Opens the post a save came from.
///
/// The URL used is the one stored on the row when it was saved, never one
/// rebuilt from the platform and the source id: a rebuilt link guesses at a
/// canonical form the platform may not use, and it cannot represent the short
/// links and share links people actually paste.
abstract final class OpenOriginal {
  /// Whether there is anything to open. A note has no source.
  static bool isAvailable(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        uri.hasScheme &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty;
  }

  /// What the button should say: "Open in TikTok", or "Open original post"
  /// when the platform is not one Nook knows by name.
  static String labelFor(String? url, String platform) {
    if (platform == NookPlatform.other) return 'Open original post';
    return 'Open in ${NookPlatform.label(platform)}';
  }

  /// Opens [url], reporting failure rather than doing nothing.
  ///
  /// [overlay] is resolved by the caller before any await, so the message still
  /// appears if the screen has gone.
  static Future<void> open(OverlayState overlay, String? url) async {
    final trimmed = url?.trim();
    if (!isAvailable(trimmed)) {
      NookToast.show(
        overlay,
        'This post has no link saved with it.',
        isError: true,
      );
      return;
    }

    final uri = Uri.parse(trimmed!);
    try {
      // externalApplication so a TikTok link opens in TikTok rather than in a
      // web view inside Nook. On the web this becomes a new tab.
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        NookToast.show(overlay, 'Could not open that link.', isError: true);
      }
    } catch (_) {
      // A malformed link, no handler installed, or a browser that blocked the
      // popup. Saying so beats a button that silently does nothing.
      NookToast.show(overlay, 'Could not open that link.', isError: true);
    }
  }
}
