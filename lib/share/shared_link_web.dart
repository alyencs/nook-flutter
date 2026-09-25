import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'shared_link.dart';

/// Web builds: the Share Target's query parameters.
///
/// `web/manifest.json` declares `share_target` with `method: GET`, so an
/// installed Nook appears in the Android share sheet and the browser opens
/// `/?shared_url=…&shared_text=…`. That is an ordinary navigation, which means
/// it works whether Nook was already running or not.
String? initialSharedLink() {
  final params = web.URLSearchParams(web.window.location.search.toJS);
  final url = params.get('shared_url');
  if (url != null && url.trim().isNotEmpty) return url.trim();
  // Some apps put the link in the text instead of the url field.
  return SharedLink.firstLinkIn(params.get('shared_text')) ??
      SharedLink.firstLinkIn(params.get('shared_title'));
}

/// Rewrites the address bar back to the app root, without a reload.
void consumeSharedLink() {
  final location = web.window.location;
  if (!location.search.contains('shared_')) return;
  web.window.history.replaceState(null, '', location.pathname);
}
