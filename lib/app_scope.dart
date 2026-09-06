import 'package:flutter/widgets.dart';

import 'ai/ai_extractor.dart';
import 'data/daos/posts_dao.dart';
import 'data/daos/searches_dao.dart';
import 'data/daos/trips_dao.dart';
import 'data/daos/users_dao.dart';
import 'data/database.dart';

/// The database, its four DAOs and the chosen extractor, handed down the tree.
///
/// Nook has no state-management package. Screens read Drift's stream queries
/// through [StreamBuilder], so saving a post updates Home, Trips and Search on
/// its own — there is no store to keep in sync and nothing to invalidate.
class AppScope extends InheritedWidget {
  AppScope({super.key, required this.db, required this.extractor, required super.child})
      : posts = PostsDao(db),
        trips = TripsDao(db),
        users = UsersDao(db),
        searches = SearchesDao(db);

  final NookDatabase db;
  final AiExtractor extractor;
  final PostsDao posts;
  final TripsDao trips;
  final UsersDao users;
  final SearchesDao searches;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      db != oldWidget.db || extractor != oldWidget.extractor;
}
