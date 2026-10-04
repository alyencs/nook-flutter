import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'ai/ai_config.dart';
import 'app.dart';
import 'app_scope.dart';
import 'data/database.dart';

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
  // Belt and braces: the seed normally runs when the database is created.
  await db.seedIfEmpty();

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
      // On in release on purpose: the live link is opened on a desktop
      // browser, where an unframed phone layout looks broken. Build with
      // --dart-define=NOOK_DEVICE_PREVIEW=false to drop it, which is how the
      // screenshots in docs/assets are captured.
      child: DevicePreview(
        enabled: const bool.fromEnvironment(
          'NOOK_DEVICE_PREVIEW',
          defaultValue: true,
        ),
        builder: (context) => const NookApp(),
      ),
    ),
  );
}
