// Custom bootstrap so CanvasKit is loaded from this app's own folder rather
// than Google's CDN.
//
// Flutter's default points canvasKitBaseUrl at gstatic.com. That makes the app
// depend on a third-party host at run time: it white-screens with no visible
// error behind a proxy, a firewall or an offline demo. The engine files are
// already copied into build/web/canvaskit by the build, so this just uses them.
{{flutter_js}}
{{flutter_build_config}}

// No service worker.
//
// Nook has no offline story to speak of — the database is already on the
// device, and tiles and the model are network either way — so all the worker
// bought was a cache that serves the previous deploy to anyone who has opened
// the link before. On a demo link that is redeployed often, that reads as "the
// fix did not work".
//
// A worker registered by an earlier build keeps serving from its cache until
// something removes it, so this clears those out as well. Both calls are
// wrapped: a browser with no service worker support, or a page served over
// plain http, throws rather than returning an empty list.
(async () => {
  try {
    const registrations =
        await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map((r) => r.unregister()));
  } catch (_) {
    // Nothing registered, or no support for them. Either way, nothing to do.
  }
  try {
    const keys = await caches.keys();
    await Promise.all(
        keys.filter((k) => k.startsWith('flutter-app')).map((k) => caches.delete(k)));
  } catch (_) {
    // No Cache Storage. Nothing was cached, so nothing is stale.
  }
})();

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
