import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:nook/widgets/open_in_maps.dart';
import 'package:nook/widgets/post_map.dart';

/// The map, tested for the three things that were actually wrong: gestures the
/// enclosing list was eating, a tile source that served a watermark instead of
/// a map, and a location that had to reach the pin.
void main() {
  /// The map never settles — tiles retry forever against a test binding that
  /// refuses every request — so these pump a bounded number of frames.
  Future<void> frames(WidgetTester tester, [int count = 3]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  InteractionOptions optionsIn(WidgetTester tester) => tester
      .widget<FlutterMap>(find.byType(FlutterMap))
      .options
      .interactionOptions;

  group('tile source', () {
    testWidgets('asks OpenStreetMap, which needs no key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PostMap(
              latitude: 35.0116,
              longitude: 135.7681,
              label: 'Kyoto',
            ),
          ),
        ),
      );
      await frames(tester);

      final layer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(
        layer.urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(
        layer.urlTemplate,
        isNot(contains('cartocdn')),
        reason: 'CARTO serves a watermark without a key',
      );
      // A watermarked 200 response is why fallbackUrl never helped: it only
      // fires on an error, and a stamped tile is not an error.
      expect(layer.fallbackUrl, isNull);
      expect(
        layer.errorTileCallback,
        isNotNull,
        reason: 'a failed tile must be reported, not left grey',
      );

      tester.takeException();
    });

    /// Tile loading is real async — an HTTP round trip and an image decode —
    /// so it needs real time, not pumped frames. runAsync gives it that, then
    /// a pump paints the result.
    Future<void> settleTiles(WidgetTester tester, Widget app) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(app);
        await Future<void>.delayed(const Duration(milliseconds: 700));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
    }

    testWidgets('says so when tiles fail instead of showing grey', (
      tester,
    ) async {
      // A host that refuses, which is what a blocked or key-gated tile server
      // looks like from here. Injected rather than left to the real client,
      // whose RetryClient backs off on timers fake time never runs.
      await settleTiles(
        tester,
        MaterialApp(
          home: Scaffold(
            body: PostMap(
              latitude: 1,
              longitude: 1,
              label: 'x',
              tileProvider: NetworkTileProvider(
                // flutter_map caches tiles on disk by default, and in a
                // test that cache answers before any request is made —
                // zero HTTP calls and nothing to succeed or fail.
                cachingProvider: const DisabledMapCachingProvider(),
                httpClient: MockClient((_) async => http.Response('nope', 404)),
              ),
            ),
          ),
        ),
      );

      expect(
        find.textContaining('could not be loaded'),
        findsOneWidget,
        reason: 'a grey rectangle explains nothing',
      );
      tester.takeException();
    });

    testWidgets('a map whose tiles arrive says nothing', (tester) async {
      // A real 1x1 PNG, so the tiles genuinely decode and the widget sees a
      // load finish rather than simply never failing.
      final pixel = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
        'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
      );

      await settleTiles(
        tester,
        MaterialApp(
          home: Scaffold(
            body: PostMap(
              latitude: 1,
              longitude: 1,
              label: 'x',
              tileProvider: NetworkTileProvider(
                // flutter_map caches tiles on disk by default, and in a
                // test that cache answers before any request is made —
                // zero HTTP calls and nothing to succeed or fail.
                cachingProvider: const DisabledMapCachingProvider(),
                httpClient: MockClient(
                  (_) async => http.Response.bytes(
                    pixel,
                    200,
                    headers: {'content-type': 'image/png'},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('could not be loaded'), findsNothing);
      // The pin is drawn over the tiles, not instead of them.
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      tester.takeException();
    });
  });

  group('gestures', () {
    testWidgets('the preview leaves one-finger drags to the page', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PostMap(latitude: 1, longitude: 1, label: 'x')),
        ),
      );
      await frames(tester);

      expect(optionsIn(tester).flags, InteractiveFlag.none);
      // Flags alone were never enough: FlutterMap always registers a
      // ScaleGestureRecognizer as its arena captain, and a one-finger drag is
      // a one-pointer scale. The preview has to not receive the pointer.
      expect(
        find.ancestor(
          of: find.byType(FlutterMap),
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsWidgets,
      );

      tester.takeException();
    });

    testWidgets('the full screen map takes every gesture but rotation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PostMap(
              latitude: 1,
              longitude: 1,
              label: 'x',
              interaction: MapInteraction.full,
            ),
          ),
        ),
      );
      await frames(tester);

      final flags = optionsIn(tester).flags;
      for (final flag in [
        InteractiveFlag.drag,
        InteractiveFlag.pinchZoom,
        InteractiveFlag.pinchMove,
        InteractiveFlag.doubleTapZoom,
        InteractiveFlag.scrollWheelZoom,
        InteractiveFlag.flingAnimation,
      ]) {
        expect(InteractiveFlag.hasFlag(flags, flag), isTrue);
      }
      expect(InteractiveFlag.hasFlag(flags, InteractiveFlag.rotate), isFalse);

      tester.takeException();
    });

    testWidgets('a preview inside a list does not block the list scrolling', (
      tester,
    ) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: const [
                SizedBox(height: 80),
                PostMap(latitude: 1, longitude: 1, label: 'x'),
                SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      );
      await frames(tester);

      expect(controller.offset, 0);
      // Dragging on the map itself must still scroll the page.
      await tester.drag(find.byType(FlutterMap), const Offset(0, -260));
      await frames(tester);
      expect(
        controller.offset,
        greaterThan(0),
        reason: 'the list keeps the single-finger drag',
      );

      tester.takeException();
      controller.dispose();
    });
  });

  group('the location reaches the pin', () {
    testWidgets('centres on the coordinates it was given', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PostMap(
              latitude: 35.0116,
              longitude: 135.7681,
              label: 'Nakazakicho',
              zoom: 14,
            ),
          ),
        ),
      );
      await frames(tester);

      final options = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;
      expect(options.initialCenter.latitude, closeTo(35.0116, 1e-9));
      expect(options.initialCenter.longitude, closeTo(135.7681, 1e-9));
      expect(options.initialZoom, 14);

      final marker = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .single;
      expect(marker.point.latitude, closeTo(35.0116, 1e-9));
      expect(marker.point.longitude, closeTo(135.7681, 1e-9));
      // The tip of the pin is the point, not its middle.
      expect(marker.alignment, Alignment.topCenter);

      expect(find.text('Nakazakicho'), findsOneWidget);
      tester.takeException();
    });

    testWidgets('tapping the preview reports it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostMap(
              latitude: 1,
              longitude: 1,
              label: 'x',
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await frames(tester);

      expect(find.text('Tap to open'), findsOneWidget);
      await tester.tap(find.byType(FlutterMap));
      await frames(tester);
      expect(taps, 1);

      tester.takeException();
    });
  });

  group('OpenInMaps', () {
    const lat = 35.0116;
    const lng = 135.7681;

    test('Android asks for a map, not for one vendor', () {
      final first = OpenInMaps.candidatesFor(
        latitude: lat,
        longitude: lng,
        label: 'Taiyo no Tou',
        platform: TargetPlatform.android,
        isWeb: false,
      ).first;

      expect(first.scheme, 'geo');
      expect(first.toString(), contains('35.011600,135.768100'));
      expect(first.toString(), contains('Taiyo%20no%20Tou'));
      // The point of geo: the system offers whatever map apps are installed.
      expect(first.host, isEmpty);
    });

    test('iOS uses the system handler, since geo: is not registered there', () {
      final first = OpenInMaps.candidatesFor(
        latitude: lat,
        longitude: lng,
        platform: TargetPlatform.iOS,
        isWeb: false,
      ).first;
      expect(first.scheme, 'maps');
      expect(first.toString(), contains('ll=35.011600,135.768100'));
    });

    test(
      'the web gets a URL, because a custom scheme has no handler there',
      () {
        final candidates = OpenInMaps.candidatesFor(
          latitude: lat,
          longitude: lng,
          platform: TargetPlatform.android,
          isWeb: true,
        );
        expect(candidates, hasLength(1));
        expect(candidates.single.scheme, 'https');
        expect(candidates.single.toString(), contains('mlat=35.011600'));
      },
    );

    test('every platform ends on something that always opens', () {
      for (final platform in TargetPlatform.values) {
        final last = OpenInMaps.candidatesFor(
          latitude: lat,
          longitude: lng,
          platform: platform,
          isWeb: false,
        ).last;
        expect(last.scheme, 'https', reason: '$platform has no fallback');
      }
    });

    test('a missing label is left out rather than sent empty', () {
      final android = OpenInMaps.candidatesFor(
        latitude: lat,
        longitude: lng,
        platform: TargetPlatform.android,
        isWeb: false,
      ).first.toString();
      expect(android, isNot(contains('()')));

      final ios = OpenInMaps.candidatesFor(
        latitude: lat,
        longitude: lng,
        label: '  ',
        platform: TargetPlatform.iOS,
        isWeb: false,
      ).first.toString();
      expect(ios, isNot(contains('q=')));
    });

    test('negative and fractional coordinates survive the round trip', () {
      final uri = OpenInMaps.candidatesFor(
        latitude: -33.8688,
        longitude: 151.2093,
        platform: TargetPlatform.android,
        isWeb: false,
      ).first.toString();
      expect(uri, contains('-33.868800,151.209300'));
    });
  });
}
