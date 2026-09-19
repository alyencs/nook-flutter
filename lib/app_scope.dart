import 'package:flutter/widgets.dart';

import 'ai/ai_extractor.dart';
import 'data/daos/posts_dao.dart';
import 'data/daos/searches_dao.dart';
import 'data/daos/settings_dao.dart';
import 'data/daos/trips_dao.dart';
import 'data/daos/users_dao.dart';
import 'data/database.dart';

/// The database, its four DAOs and the chosen extractor, handed down the tree.
///
/// Nook has no state-management package. Screens read Drift's stream queries
/// through [StreamBuilder], so saving a post updates Home, Trips and Search on
/// its own — there is no store to keep in sync and nothing to invalidate.
class AppScope extends InheritedWidget {
  AppScope({
    super.key,
    required this.db,
    required this.extractor,
    required this.tab,
    required super.child,
  })
      : posts = PostsDao(db),
        trips = TripsDao(db),
        users = UsersDao(db),
        searches = SearchesDao(db),
        settings = SettingsDao(db);

  final NookDatabase db;
  final AiExtractor extractor;

  /// Which root tab is showing.
  ///
  /// Shared rather than held in [RootShell] because the profile sub-screens are
  /// pushed routes that still draw the tab bar — the mockup shows it on all of
  /// them — and tapping a tab there has to reach the shell underneath.
  final ValueNotifier<int> tab;
  final PostsDao posts;
  final TripsDao trips;
  final UsersDao users;
  final SearchesDao searches;
  final SettingsDao settings;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      db != oldWidget.db || extractor != oldWidget.extractor || tab != oldWidget.tab;
}
