import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'ai/ai_config.dart';
import 'ai/geocoder.dart';
import 'app.dart';
import 'app_scope.dart';
import 'data/database.dart';
import 'preview/preview_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reads .env if the bundle has one. A build without an API key is a normal
  // state, not a failure: it is what every deployed build looks like, and the
  // sample extractor takes over. See docs/06-security-and-privacy.md.
  await NookAi.load();

  final db = NookDatabase();
  // Created once, here, and never inside a builder that reruns: DevicePreview
  // calls its `builder` on every preview rebuild, and an extractor built in
  // there would be replaced each time, taking its in-flight request map with
  // it.
  final tab = ValueNotifier<int>(0);
  final extractor = NookAi.createExtractor();
  final itinerary = NookAi.createItineraryGenerator();
  // No key and no billing account, so this runs in every build, deployed
  // included: it is the same OpenStreetMap project the tiles come from.
  final geocoder = NominatimGeocoder();

  runApp(
    // AppScope sits above DevicePreview, not inside its builder: DevicePreview
    // mounts the builder's result under a GlobalKey it attaches in several
    // branches, so anything built in there is reparented whenever the preview
    // changes. Up here the scope is one instance, one element, never moved.
    AppScope(
      db: db,
      tab: tab,
      extractor: extractor,
      itinerary: itinerary,
      geocoder: geocoder,
      // On in release on purpose: the live link is opened on a desktop
      // browser, where an unframed phone layout looks broken, and the panel is
      // how the device and its size are chosen. Build with
      // --dart-define=NOOK_DEVICE_PREVIEW=false to drop it, which is how the
      // screenshots in docs/assets are captured.
      child: DevicePreview(
        enabled: const bool.fromEnvironment(
          'NOOK_DEVICE_PREVIEW',
          defaultValue: true,
        ),
        // Keeps the device, its size and the rest of the panel's settings
        // between visits, but never restores the panel in a state where it
        // cannot be used. See RecoverablePreviewStorage.
        storage: RecoverablePreviewStorage(),
        builder: (context) => const NookApp(),
      ),
    ),
  );

  // After the first frame, not before it.
  //
  // The seed normally runs inside the migration, so this only has work to do
  // when the database exists but is empty. Awaiting it ahead of `runApp` meant
  // the whole app waited on a query: on the web the database lives behind a
  // worker, and a browser that cannot grant it — a second tab holding the
  // lock, storage refused in a private window — leaves that future unfinished
  // and `runApp` is never reached. What the visitor gets then is the page
  // background and nothing else, with no error anywhere, which is the one
  // failure a live link cannot be allowed to have. Started here it cannot
  // stop the app from appearing; the shell shows the library the moment the
  // rows land.
  unawaited(db.seedIfEmpty());
}

/// Starts a future and deliberately does not wait for it.
///
/// `dart:async`'s own `unawaited` would do, but importing the whole library
/// into `main` for one line costs more than saying it here.
void unawaited(Future<void> future) {
  future.catchError((Object error) {
    // A seed that cannot run is an empty library, not a broken app. The
    // screens all handle having no rows.
    debugPrint('Seeding skipped: $error');
  });
}
