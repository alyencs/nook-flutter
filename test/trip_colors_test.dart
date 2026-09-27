import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/daos/trips_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/theme/trip_colors.dart';

/// Folder colours: five of them, chosen once and remembered.
void main() {
  late NookDatabase db;
  late TripsDao trips;
  late int userId;

  setUp(() async {
    db = NookDatabase.forTesting(NativeDatabase.memory());
    await db.delete(db.savedPosts).go();
    await db.delete(db.trips).go();
    await db.delete(db.users).go();
    trips = TripsDao(db);
    userId = await db
        .into(db.users)
        .insert(UsersCompanion.insert(name: 'Alyen'));
  });

  tearDown(() => db.close());

  test('there are exactly five, and they are all distinct', () {
    expect(TripColor.values, hasLength(5));
    expect(
      TripColor.values.map((c) => c.fill).toSet(),
      hasLength(5),
      reason: 'two identical fills would defeat the purpose',
    );
    expect(TripColor.values.map((c) => c.id).toSet(), hasLength(5));
    expect(TripColor.values.map((c) => c.label).toSet(), hasLength(5));
  });

  test('every fill is pale enough to read dark text and an ink icon on', () {
    for (final colour in TripColor.values) {
      expect(
        colour.fill.computeLuminance(),
        greaterThan(0.6),
        reason: '${colour.label} is too dark to be a pastel',
      );
      // And the ink has to stand out on it.
      expect(
        colour.ink.computeLuminance(),
        lessThan(colour.fill.computeLuminance()),
        reason: '${colour.label} ink does not contrast with its fill',
      );
    }
  });

  test('a chosen colour survives being written and read back', () async {
    await trips.createTrip('Japan 2027', userId, colour: TripColor.sky);

    final summary = (await trips.watchTripSummaries().first).single;
    expect(summary.colour, TripColor.sky);
    expect(summary.trip.colorId, 'sky');
  });

  test('changing the colour persists', () async {
    final id = await trips.createTrip(
      'Japan 2027',
      userId,
      colour: TripColor.sky,
    );

    await trips.setColour(id, TripColor.fern);

    final summary = (await trips.watchTripSummaries().first).single;
    expect(summary.colour, TripColor.fern);
  });

  test('a trip created before the feature still gets a colour', () async {
    // colorId null is what every existing row looks like after the migration.
    await trips.createTrip('Japan 2027', userId);

    final summary = (await trips.watchTripSummaries().first).single;
    expect(summary.trip.colorId, isNull);
    expect(TripColor.values, contains(summary.colour));
  });

  test('uncoloured trips are spread across the palette, not all one', () {
    // Five consecutive ids should produce five different colours, so an old
    // library is not a wall of sand.
    final spread = [for (var id = 1; id <= 5; id++) TripColor.forId(id)];
    expect(spread.toSet(), hasLength(5));
  });

  test('the same trip is the same colour every time it is resolved', () {
    for (var id = 1; id <= 20; id++) {
      expect(TripColor.forId(id), TripColor.forId(id));
    }
  });

  test('an unknown stored value falls back instead of throwing', () {
    expect(TripColor.parse('chartreuse'), TripColor.fallback);
    expect(TripColor.parse(null), TripColor.fallback);
    expect(TripColor.parse(''), TripColor.fallback);
  });

  test('a stored choice beats the id-derived default', () {
    final byId = TripColor.forId(3);
    final other = TripColor.values.firstWhere((c) => c != byId);

    expect(tripColourOf(id: 3, colorId: other.id), other);
    expect(tripColourOf(id: 3, colorId: null), byId);
  });
}
