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
  // Belt and braces: the seed normally runs when the database is created.
  await db.seedIfEmpty();

  runApp(
    // Kept from the starter, and left on in release on purpose: the live link
    // is opened on a desktop browser, where an unframed phone layout looks
    // broken.
    //
    // Build with --dart-define=NOOK_DEVICE_PREVIEW=false to drop the frame.
    // That is how the phone-sized screenshots in docs/assets are captured; the
    // deployed build keeps the frame.
    DevicePreview(
      enabled: const bool.fromEnvironment(
        'NOOK_DEVICE_PREVIEW',
        defaultValue: true,
      ),
      builder: (context) => AppScope(
        db: db,
        extractor: NookAi.createExtractor(),
        child: const NookApp(),
      ),
    ),
  );
}
