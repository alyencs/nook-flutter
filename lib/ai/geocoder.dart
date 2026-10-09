import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'location_scope.dart';

/// A point on the map.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Inside the real ranges, and not the null island that a failed parse
  /// produces.
  static GeoPoint? validated(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    if (latitude == 0 && longitude == 0) return null;
    return GeoPoint(latitude, longitude);
  }

  @override
  String toString() => '$latitude,$longitude';
}

/// What to look up, and how broad an answer to accept.
class GeocodeQuery {
  const GeocodeQuery({required this.text, required this.scope});

  final String text;
  final LocationScope scope;

  /// The query for a post, built from its location fields, most specific
  /// first: "Kissa Master, Gion, Kyoto, Japan" finds the cafe, where "Kyoto"
  /// alone would only find the city.
  ///
  /// Null when there is nothing geographic to ask about. [destination] is used
  /// on its own only when no structured field survived extraction.
  static GeocodeQuery? forPost({
    String? placeName,
    String? address,
    String? neighbourhood,
    String? city,
    String? region,
    String? country,
    String? destination,
  }) {
    final scope = LocationScope.of(
      placeName: placeName,
      address: address,
      neighbourhood: neighbourhood,
      city: city,
      region: region,
      country: country,
      destination: destination,
    );
    if (!scope.isMappable) return null;

    final parts = <String>[
      ?_clean(placeName),
      ?_clean(address),
      ?_clean(neighbourhood),
      ?_clean(city),
      ?_clean(region),
      ?_clean(country),
    ];
    final text = parts.isEmpty ? _clean(destination) : parts.join(', ');
    if (text == null || text.isEmpty) return null;

    return GeocodeQuery(text: text, scope: scope);
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Two queries for the same place are the same lookup, whatever the case.
  String get cacheKey => '${scope.name}|${text.toLowerCase()}';
}

/// Turns a place's name into a point, so a post that was saved without
/// coordinates can still be shown on a map.
abstract interface class Geocoder {
  Future<GeoPoint?> lookup(GeocodeQuery query);
}

/// Answers nothing, for builds and tests that should make no network call.
class NoGeocoder implements Geocoder {
  const NoGeocoder();

  @override
  Future<GeoPoint?> lookup(GeocodeQuery query) async => null;
}

/// Nominatim, the OpenStreetMap gazetteer.
///
/// The same project the tiles come from, so it needs no key and no billing
/// account, and it sends CORS headers, which is what makes it usable from a
/// browser at all.
///
/// Two things keep it within OSM's usage policy: one request per place, cached
/// for the life of the session, and a resolved point is written back onto the
/// post so the question is never asked twice.
class NominatimGeocoder implements Geocoder {
  NominatimGeocoder({http.Client? httpClient, this.timeout = _timeout})
    : _http = httpClient ?? http.Client();

  static const _host = 'nominatim.openstreetmap.org';
  static const _timeout = Duration(seconds: 8);

  final http.Client _http;
  final Duration timeout;

  /// Resolved and unresolvable queries both, so a place that does not exist is
  /// not asked for a second time.
  final _cache = <String, GeoPoint?>{};

  /// Lookups in flight, so two widgets asking at once make one request.
  final _inFlight = <String, Future<GeoPoint?>>{};

  @override
  Future<GeoPoint?> lookup(GeocodeQuery query) {
    final key = query.cacheKey;
    if (_cache.containsKey(key)) return Future.value(_cache[key]);

    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _lookup(query).then((point) {
      _cache[key] = point;
      return point;
    });
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  Future<GeoPoint?> _lookup(GeocodeQuery query) async {
    final uri = Uri.https(_host, '/search', {
      'q': query.text,
      'format': 'jsonv2',
      'limit': '1',
      'addressdetails': '0',
      // Narrows a broad query to the kind of thing being asked for, so a
      // country-scope lookup cannot land on a hamlet of the same name.
      if (query.scope.featureType != null) 'featureType': query.scope.featureType!,
    });

    try {
      final response = await _http
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      return parseFirst(utf8.decode(response.bodyBytes));
    } catch (_) {
      // Offline, blocked, rate-limited or a changed shape. A map that cannot
      // be placed is a placeholder, not a failed screen.
      return null;
    }
  }

  void close() => _http.close();

  /// The first usable point in a Nominatim response, or null.
  ///
  /// Visible for tests: the parse is the part worth pinning down, and it is the
  /// part that a changed response shape would break.
  static GeoPoint? parseFirst(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! List || decoded.isEmpty) return null;

    final first = decoded.first;
    if (first is! Map) return null;

    return GeoPoint.validated(_number(first['lat']), _number(first['lon']));
  }

  /// Nominatim sends the coordinates as strings.
  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
