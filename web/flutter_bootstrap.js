// Custom bootstrap so CanvasKit is loaded from this app's own folder rather
// than Google's CDN.
//
// Flutter's default points canvasKitBaseUrl at gstatic.com. That makes the app
// depend on a third-party host at run time: it white-screens with no visible
// error behind a proxy, a firewall or an offline demo. The engine files are
// already copied into build/web/canvaskit by the build, so this just uses them.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
