import 'package:drift/drift.dart';

import '../database.dart';

class UsersDao {
  UsersDao(this._db);

  final NookDatabase _db;

  /// The local profile, or null when the app has never been set up. This is
  /// what decides whether launch goes to onboarding or straight to Home.
  Stream<User?> watchCurrentUser() =>
      (_db.select(_db.users)..limit(1)).watchSingleOrNull();

  Future<User?> currentUser() =>
      (_db.select(_db.users)..limit(1)).getSingleOrNull();

  /// Writes the local profile.
  ///
  /// The seed inserts a nameless row so trips have a user to belong to, so this
  /// fills that row in rather than adding a second one. Only if there is no row
  /// at all — after "Clear All Data" — does it insert.
  Future<int> saveProfile({
    required String name,
    required String email,
    String? profilePicture,
  }) async {
    final existing = await currentUser();
    if (existing == null) {
      return _db.into(_db.users).insert(
            UsersCompanion.insert(
              name: name,
              email: email,
              profilePicture: Value(profilePicture),
            ),
          );
    }
    await updateProfile(
      existing.id,
      name: name,
      email: email,
      profilePicture: profilePicture,
    );
    return existing.id;
  }

  Future<void> updateProfile(
    int id, {
    String? name,
    String? email,
    String? profilePicture,
  }) {
    return (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        name: name == null ? const Value.absent() : Value(name),
        email: email == null ? const Value.absent() : Value(email),
        profilePicture: profilePicture == null
            ? const Value.absent()
            : Value(profilePicture),
      ),
    );
  }
}
