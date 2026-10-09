import 'package:flutter/material.dart';

import 'ai/ai_config.dart';
import 'ai/geocoder.dart';
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
  // Created once, here, rather than in a builder: a builder runs again on
  // every resize, and an extractor built in one would be replaced each time,
  // taking its in-flight request map and its resolved-model cache with it.
  final tab = ValueNotifier<int>(0);
  final extractor = NookAi.createExtractor();
  final itinerary = NookAi.createItineraryGenerator();
  // No key and no billing account, so this runs in every build, deployed
  // included: it is the same OpenStreetMap project the tiles come from.
  final geocoder = NominatimGeocoder();
  // Belt and braces: the seed normally runs when the database is created.
  await db.seedIfEmpty();

  runApp(
    AppScope(
      db: db,
      tab: tab,
      extractor: extractor,
      itinerary: itinerary,
      geocoder: geocoder,
      child: const NookApp(),
    ),
  );
}
