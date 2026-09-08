import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'ai/ai_config.dart';
import 'app.dart';
import 'app_scope.dart';
import 'data/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reads .env if the bundle has one. A build without a Gemini key is a normal
  // state, not a failure: it is what every deployed build looks like, and the
  // sample extractor takes over. See docs/06-security-and-privacy.md.
  await NookAi.load();

  final db = NookDatabase();
  // These three are the app's identity, so they are created once, here, and
  // never inside a builder that reruns. DevicePreview calls its `builder` on
  // every preview rebuild — four times before the first frame has settled — and
  // a GeminiExtractor built in there would be replaced each time, taking its
  // in-flight request map and its resolved-model cache with it.
  final tab = ValueNotifier<int>(0);
  final extractor = NookAi.createExtractor();
  // Belt and braces: the seed normally runs when the database is created.
  await db.seedIfEmpty();

  runApp(
    // AppScope sits ABOVE DevicePreview, not inside its builder.
    //
    // DevicePreview mounts whatever its builder returns under a single
    // GlobalKey (`_appKey`) that it attaches in four different branches of its
    // own build. Switching branches reparents that entire subtree. Anything
    // built inside the builder is therefore rebuilt on every preview change and
    // reparented on every branch change — including, previously, the one
    // InheritedWidget every screen in Nook depends on. Above it, the scope is
    // outside all of that: one instance, one element, never moved.
    AppScope(
      db: db,
      tab: tab,
      extractor: extractor,
      // Kept from the starter, and left on in release on purpose: the live link
      // is opened on a desktop browser, where an unframed phone layout looks
      // broken.
      //
      // Build with --dart-define=NOOK_DEVICE_PREVIEW=false to drop the frame.
      // That is how the phone-sized screenshots in docs/assets are captured;
      // the deployed build keeps the frame.
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
