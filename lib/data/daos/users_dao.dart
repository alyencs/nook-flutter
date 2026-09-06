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

  Future<int> createProfile({
    required String name,
    required String email,
    String? profilePicture,
  }) {
    return _db.into(_db.users).insert(
          UsersCompanion.insert(
            name: name,
            email: email,
            profilePicture: Value(profilePicture),
          ),
        );
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
