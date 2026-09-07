import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/daos/trips_dao.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_empty_state.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_text_field.dart';
import '../../widgets/saved_post_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/trip_card.dart';
import '../add/add_method_screen.dart';
import '../details/post_details_screen.dart';
import '../search/search_screen.dart';
import '../trips/trip_details_screen.dart';
import '../trips/trips_screen.dart';
import 'post_list_screen.dart';

/// H1 / H2 / H3 / H4. The screen a returning traveller lives in.
///
/// Section order follows H1, the canonical "Home (Default)" frame: Recent
/// Saves, then Your Trips, then Recently Viewed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.nav,
    required this.searching,
    required this.onStartSearch,
  });

  final Widget nav;

  /// Search is a state of this tab, not a separate route: the mockup draws the
  /// tab bar on the search frames and names them "Home: Search".
  final bool searching;
  final VoidCallback onStartSearch;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    if (searching) {
      return NookScaffold(bottomNav: nav, child: const SearchBody());
    }

    return NookScaffold(
      bottomNav: nav,
      padHorizontal: false,
      child: StreamBuilder<List<SavedPost>>(
        stream: scope.posts.watchRecentSaves(),
        builder: (context, recentSnapshot) {
          return StreamBuilder<List<TripSummary>>(
            stream: scope.trips.watchTripSummaries(),
            builder: (context, tripSnapshot) {
              final recent = recentSnapshot.data ?? const <SavedPost>[];
              final trips = tripSnapshot.data ?? const <TripSummary>[];
              final loading =
                  recentSnapshot.connectionState == ConnectionState.waiting ||
                      tripSnapshot.connectionState == ConnectionState.waiting;
              final empty = recent.isEmpty && trips.isEmpty;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  NookSpacing.screenEdge,
                  NookSpacing.section,
                  NookSpacing.screenEdge,
                  NookSpacing.screenEdge,
                ),
                children: [
                  const _Greeting(),
                  const SizedBox(height: NookSpacing.section),
                  NookSearchBar(
                    controller: TextEditingController(),
                    readOnly: true,
                    onTap: onStartSearch,
                  ),
                  if (loading)
                    const SizedBox.shrink()
                  else if (empty)
                    const _HomeEmpty()
                  else ...[
                    const SizedBox(height: NookSpacing.screenEdge),
                    if (recent.isNotEmpty) _RecentSaves(posts: recent),
                    if (trips.isNotEmpty) _YourTrips(trips: trips),
                    const _RecentlyViewed(),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'morning'
        : hour < 18
            ? 'afternoon'
            : 'evening';

    return StreamBuilder<User?>(
      stream: AppScope.of(context).users.watchCurrentUser(),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good $part,',
              style: NookType.body.copyWith(
                color: NookColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              snapshot.data?.name ?? '',
              style: NookType.display,
            ),
          ],
        );
      },
    );
  }
}

/// H3. The one screen that says what to do next rather than showing nothing.
class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: NookEmptyState(
        icon: Icons.bookmark_outline_rounded,
        title: 'No trips yet — save your first find',
        message: 'Paste a link from TikTok, Instagram, or YouTube to start '
            'building your first trip.',
        actionLabel: 'Save First Find',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddMethodScreen()),
        ),
      ),
    );
  }
}

class _RecentSaves extends StatelessWidget {
  const _RecentSaves({required this.posts});

  final List<SavedPost> posts;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Recent Saves',
          onSeeAll: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostListScreen(
                title: 'Recent Saves',
                posts: scope.posts.watchAll(),
              ),
            ),
          ),
        ),
        const SizedBox(height: NookSpacing.section),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: NookSpacing.section),
            itemBuilder: (context, index) => SavedPostGridCard(
              post: posts[index],
              onTap: () => openPostDetails(context, posts[index].id),
            ),
          ),
        ),
        const SizedBox(height: NookSpacing.screenEdge),
      ],
    );
  }
}

class _YourTrips extends StatelessWidget {
  const _YourTrips({required this.trips});

  final List<TripSummary> trips;

  @override
  Widget build(BuildContext context) {
    final shown = trips.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Your Trips',
          onSeeAll: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TripsScreenRoute()),
          ),
        ),
        const SizedBox(height: NookSpacing.section),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = NookSpacing.section;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final summary in shown)
                  SizedBox(
                    width: width,
                    child: TripCard(
                      summary: summary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TripDetailsScreen(tripId: summary.trip.id),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: NookSpacing.screenEdge),
      ],
    );
  }
}

class _RecentlyViewed extends StatelessWidget {
  const _RecentlyViewed();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<List<SavedPost>>(
      stream: scope.posts.watchRecentlyViewed(limit: 3),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? const <SavedPost>[];
        if (posts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Recently Viewed',
              onSeeAll: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostListScreen(
                    title: 'Recently Viewed',
                    posts: scope.posts.watchRecentlyViewed(limit: 50),
                    emptyMessage: 'Posts you open show up here.',
                  ),
                ),
              ),
            ),
            const SizedBox(height: NookSpacing.section),
            for (final post in posts) ...[
              SavedPostRowCard(
                post: post,
                onTap: () => openPostDetails(context, post.id),
              ),
              const SizedBox(height: NookSpacing.section),
            ],
          ],
        );
      },
    );
  }
}
