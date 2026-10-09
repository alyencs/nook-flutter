import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:nook/ai/geocoder.dart';
import 'package:nook/ai/location_scope.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/details/travel_details_screen.dart';
import 'package:nook/theme/nook_theme.dart';
import 'package:nook/widgets/post_map.dart';

/// Every saved post that names somewhere gets a map.
///
/// The thing that changes with how broad the place is, is the frame — not
/// whether a map is drawn at all. A post about Korea is a map of Korea.

void main() {
  group('how broad the place is', () {
    test('reads off the most specific field that was filled in', () {
      expect(
        LocationScope.of(placeName: 'Kissa Master', city: 'Kyoto'),
        LocationScope.venue,
      );
      expect(
        LocationScope.of(neighbourhood: 'Gion', city: 'Kyoto'),
        LocationScope.district,
      );
      expect(
        LocationScope.of(city: 'Kyoto', country: 'Japan'),
        LocationScope.city,
      );
      expect(
        LocationScope.of(region: 'Kansai', country: 'Japan'),
        LocationScope.region,
      );
      expect(LocationScope.of(country: 'South Korea'), LocationScope.country);
    });

    test('a bare destination is somewhere, of an unknown size', () {
      expect(
        LocationScope.of(destination: 'Southeast Asia'),
        LocationScope.area,
      );
      expect(LocationScope.area.isMappable, isTrue);
    });

    test('nothing at all is the only unmappable answer', () {
      expect(LocationScope.of(), LocationScope.none);
      expect(LocationScope.of(city: '   '), LocationScope.none);
      expect(LocationScope.none.isMappable, isFalse);
    });

    test('the frame widens as the place does', () {
      final zooms = [
        LocationScope.venue,
        LocationScope.district,
        LocationScope.city,
        LocationScope.region,
        LocationScope.country,
      ].map((scope) => scope.zoom).toList();

      for (var i = 1; i < zooms.length; i++) {
        expect(
          zooms[i],
          lessThan(zooms[i - 1]),
          reason: 'each step out is zoomed further out than the last',
        );
      }
    });
  });

  group('the geocoder query', () {
    test('is built most specific first, so a venue is found as a venue', () {
      final query = GeocodeQuery.forPost(
        placeName: 'Kissa Master',
        neighbourhood: 'Gion',
        city: 'Kyoto',
        country: 'Japan',
      );

      expect(query!.text, 'Kissa Master, Gion, Kyoto, Japan');
      expect(query.scope, LocationScope.venue);
      expect(
        query.scope.featureType,
        isNull,
        reason: 'a venue search must not be narrowed to settlements',
      );
    });

    test('a country search is narrowed to countries', () {
      final query = GeocodeQuery.forPost(country: 'South Korea');

      expect(query!.text, 'South Korea');
      expect(query.scope.featureType, 'country');
    });

    test('falls back to the display destination when nothing else survived', () {
      final query = GeocodeQuery.forPost(destination: 'Southeast Asia');

      expect(query!.text, 'Southeast Asia');
      expect(query.scope, LocationScope.area);
    });

    test('a post with no location asks nothing', () {
      expect(GeocodeQuery.forPost(), isNull);
      expect(GeocodeQuery.forPost(destination: '  '), isNull);
    });

    test('the same place is one cache key, whatever the case', () {
      expect(
        GeocodeQuery.forPost(city: 'Kyoto')!.cacheKey,
        GeocodeQuery.forPost(city: 'KYOTO')!.cacheKey,
      );
    });
  });

  group('reading what the gazetteer sends back', () {
    test('coordinates arrive as strings and are parsed', () {
      final point = NominatimGeocoder.parseFirst(
        jsonEncode([
          {'lat': '35.0116', 'lon': '135.7681', 'name': 'Kyoto'},
        ]),
      );

      expect(point!.latitude, closeTo(35.0116, 0.0001));
      expect(point.longitude, closeTo(135.7681, 0.0001));
    });

    test('an empty answer, a broken one and a null island are all null', () {
      expect(NominatimGeocoder.parseFirst('[]'), isNull);
      expect(NominatimGeocoder.parseFirst('not json'), isNull);
      expect(NominatimGeocoder.parseFirst('{"lat":"1"}'), isNull);
      expect(
        NominatimGeocoder.parseFirst('[{"lat":"0","lon":"0"}]'),
        isNull,
        reason: '0,0 is what a failed parse looks like, not a place',
      );
      expect(
        NominatimGeocoder.parseFirst('[{"lat":"99","lon":"10"}]'),
        isNull,
        reason: 'outside the real range',
      );
    });

    test('the scope narrows the request, and one place is asked once', () async {
      final asked = <Uri>[];
      final geocoder = NominatimGeocoder(
        httpClient: MockClient((request) async {
          asked.add(request.url);
          return http.Response(
            jsonEncode([
              {'lat': '35.9078', 'lon': '127.7669'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final query = GeocodeQuery.forPost(country: 'South Korea')!;
      final first = await geocoder.lookup(query);
      final second = await geocoder.lookup(query);

      expect(first!.latitude, closeTo(35.9078, 0.001));
      expect(second!.latitude, closeTo(35.9078, 0.001));
      expect(asked, hasLength(1), reason: 'the second answer is cached');
      expect(asked.single.host, 'nominatim.openstreetmap.org');
      expect(asked.single.queryParameters['featureType'], 'country');
      expect(asked.single.queryParameters['q'], 'South Korea');
    });

    test('a place that is not found is not asked for twice', () async {
      var calls = 0;
      final geocoder = NominatimGeocoder(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }),
      );

      final query = GeocodeQuery.forPost(country: 'Nowhere At All')!;
      expect(await geocoder.lookup(query), isNull);
      expect(await geocoder.lookup(query), isNull);
      expect(calls, 1);
    });

    test('a refusal or a dead network is a null, not a thrown screen', () async {
      final refused = NominatimGeocoder(
        httpClient: MockClient((_) async => http.Response('nope', 403)),
      );
      final dead = NominatimGeocoder(
        httpClient: MockClient((_) async => throw http.ClientException('down')),
      );

      final query = GeocodeQuery.forPost(city: 'Kyoto')!;
      expect(await refused.lookup(query), isNull);
      expect(await dead.lookup(query), isNull);
    });
  });

  group('Travel Details draws a map for every located post', () {
    late NookDatabase db;

    setUp(() => db = NookDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> savePost({
      String? destination,
      String? placeName,
      String? city,
      String? country,
      double? latitude,
      double? longitude,
    }) {
      return PostsDao(db).insertPost(
        SavedPostsCompanion.insert(
          title: 'A post',
          platform: 'tiktok',
          importMethod: 'link',
          dateSaved: DateTime.now(),
          aiDestination: Value(destination),
          aiPlaceName: Value(placeName),
          aiCity: Value(city),
          aiCountry: Value(country),
          aiLatitude: Value(latitude),
          aiLongitude: Value(longitude),
        ),
      );
    }

    Future<void> pump(WidgetTester tester, int id, {Geocoder? geocoder}) async {
      tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          db: db,
          tab: ValueNotifier<int>(0),
          extractor: const SampleExtractor(),
          geocoder: geocoder,
          child: MaterialApp(
            theme: NookTheme.theme,
            home: TravelDetailsScreen(postId: id),
          ),
        ),
      );
      // Bounded, because the map's tiles and the pin's animation keep a frame
      // scheduled and pumpAndSettle would never return.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('a country gets a map, not a refusal', (tester) async {
      final id = await savePost(
        destination: 'South Korea',
        country: 'South Korea',
        latitude: 35.9078,
        longitude: 127.7669,
      );
      await pump(tester, id);

      expect(find.byType(PostMap), findsOneWidget);
      expect(find.byType(PostMapPlaceholder), findsNothing);
      expect(find.textContaining('too broad'), findsNothing);

      final map = tester.widget<PostMap>(find.byType(PostMap));
      expect(map.zoom, LocationScope.country.zoom);
      expect(map.label, 'South Korea');
      await unmount(tester);
    });

    testWidgets('a venue is framed closer than a country', (tester) async {
      final id = await savePost(
        destination: 'Kissa Master, Kyoto',
        placeName: 'Kissa Master',
        city: 'Kyoto',
        country: 'Japan',
        latitude: 35.0116,
        longitude: 135.7681,
      );
      await pump(tester, id);

      final map = tester.widget<PostMap>(find.byType(PostMap));
      expect(map.zoom, LocationScope.venue.zoom);
      expect(map.zoom, greaterThan(LocationScope.country.zoom));
      await unmount(tester);
    });

    testWidgets('a post saved without coordinates is looked up', (tester) async {
      final id = await savePost(destination: 'South Korea', country: 'South Korea');
      final geocoder = NominatimGeocoder(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode([
              {'lat': '35.9078', 'lon': '127.7669'},
            ]),
            200,
          ),
        ),
      );

      await pump(tester, id, geocoder: geocoder);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(find.byType(PostMap), findsOneWidget);

      // Written back, so the next visit needs no lookup at all. A Future read
      // rather than the DAO's stream: a Drift stream awaited inside
      // testWidgets never returns, because the fake clock only advances while
      // the tester pumps.
      final saved = await (db.select(
        db.savedPosts,
      )..where((p) => p.id.equals(id))).getSingle();
      expect(saved.aiLatitude, closeTo(35.9078, 0.001));
      expect(saved.aiLongitude, closeTo(127.7669, 0.001));
      await unmount(tester);
    });

    testWidgets('a place that cannot be found says so plainly', (tester) async {
      final id = await savePost(destination: 'Narnia', country: 'Narnia');
      final geocoder = NominatimGeocoder(
        httpClient: MockClient((_) async => http.Response('[]', 200)),
      );

      await pump(tester, id, geocoder: geocoder);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(find.byType(PostMap), findsNothing);
      expect(find.byType(PostMapPlaceholder), findsOneWidget);
      expect(find.textContaining('could not find'), findsOneWidget);
      expect(find.textContaining('too broad'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a post that names nowhere keeps the placeholder', (
      tester,
    ) async {
      final id = await savePost();
      await pump(tester, id);

      expect(find.byType(PostMap), findsNothing);
      expect(find.textContaining('No destination was detected'), findsOneWidget);
      await unmount(tester);
    });
  });
}
