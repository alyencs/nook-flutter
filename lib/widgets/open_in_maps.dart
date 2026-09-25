import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'nook_toast.dart';

/// Hands a saved location to whatever map app the device already uses.
///
/// Deliberately not "open Google Maps" or "open Apple Maps". Android's `geo:`
/// scheme is a request for *a* map, and the system offers whichever map apps
/// are installed — Google Maps, Organic Maps, whatever the person actually
/// chose. iOS has no equivalent generic scheme, so `maps:` goes to the system
/// handler there. Only when neither exists does this fall back to a web URL,
/// and that URL is OpenStreetMap, which is where Nook's own tiles come from.
abstract final class OpenInMaps {
  /// Six decimals is about 0.1m — past the precision any extraction has, and
  /// short enough to stay readable in a URL.
  static String _c(double value) => value.toStringAsFixed(6);

  /// The URIs to try, best first.
  ///
  /// Split out from [open] so the choice can be tested without launching
  /// anything: this is the part with the platform logic in it.
  static List<Uri> candidatesFor({
    required double latitude,
    required double longitude,
    String? label,
    TargetPlatform? platform,
    bool? isWeb,
  }) {
    final lat = _c(latitude);
    final lng = _c(longitude);
    final name = label?.trim();
    final web = isWeb ?? kIsWeb;
    final target = platform ?? defaultTargetPlatform;

    // Always available, and the only option in a browser, where a custom
    // scheme would either be ignored or prompt for an app that cannot exist.
    final fallback = Uri.parse(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng',
    );
    if (web) return [fallback];

    return switch (target) {
      // `q` with the coordinates repeated drops a labelled pin rather than
      // running a search, which is what a bare `geo:lat,lng` does on some
      // versions. The label is parenthesised per the scheme.
      TargetPlatform.android || TargetPlatform.fuchsia => [
        Uri.parse(
          'geo:$lat,$lng?q=$lat,$lng'
          '${name == null || name.isEmpty ? '' : '(${Uri.encodeComponent(name)})'}',
        ),
        fallback,
      ],
      TargetPlatform.iOS || TargetPlatform.macOS => [
        Uri.parse(
          'maps:?ll=$lat,$lng'
          '${name == null || name.isEmpty ? '' : '&q=${Uri.encodeComponent(name)}'}',
        ),
        fallback,
      ],
      // Linux and Windows have no agreed scheme; the browser is the map app.
      _ => [fallback],
    };
  }

  /// Opens the first candidate the device can handle.
  ///
  /// [overlay] is resolved by the caller before any await, so a failure is
  /// still reported if the screen has gone.
  static Future<void> open(
    OverlayState overlay, {
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final candidates = candidatesFor(
      latitude: latitude,
      longitude: longitude,
      label: label,
    );

    for (final uri in candidates) {
      try {
        // canLaunchUrl is the question "is there an app for this scheme".
        // On the last candidate it is skipped: an https URL always has a
        // handler, and on some platforms the check is stricter than reality.
        final last = uri == candidates.last;
        if (!last && !await canLaunchUrl(uri)) continue;
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
        if (launched) return;
      } catch (_) {
        // Try the next one rather than failing on the first missing handler.
        continue;
      }
    }

    NookToast.show(overlay, 'Could not open a map app.', isError: true);
  }
}
