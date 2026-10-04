import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/daos/trips_dao.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_empty_state.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/section_header.dart';
import '../../widgets/trip_card.dart';
import '../../widgets/folder_motion.dart';
import '../add/add_method_screen.dart';
import '../explore/explore_itineraries_screen.dart';
import 'trip_details_screen.dart';

/// The Trips tab.
///
/// The mockup never drew this screen, but the tab bar has a Trips tab and MVP
/// feature #3 needs somewhere to browse them. Built from the same cards, grid
/// and spacing as everything else.
class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key, required this.nav});

  final Widget nav;

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomNav: nav,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: NookSpacing.section),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NookSpacing.tight),
            child: const ScreenTitle('Your Trips'),
          ),
          // The way into the catalogue. The same section mark Home uses to
          // reach its other screens, so this is one more place a rule carries
          // the eye across to an action rather than a new kind of control.
          SectionHeader(
            'Explore itineraries',
            onSeeAll: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ExploreItinerariesScreen(),
              ),
            ),
          ),
          const SizedBox(height: NookSpacing.tight),
          const Expanded(child: TripsBody()),
        ],
      ),
    );
  }
}

/// The same list, reached from Home's "See All" rather than the tab.
class TripsScreenRoute extends StatelessWidget {
  const TripsScreenRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const NookScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NookAppBar(title: 'Your Trips'),
          Expanded(child: TripsBody()),
        ],
      ),
    );
  }
}

class TripsBody extends StatefulWidget {
  const TripsBody({super.key});

  @override
  State<TripsBody> createState() => _TripsBodyState();
}

class _TripsBodyState extends State<TripsBody> {
  /// The trip created a moment ago, so exactly one folder springs in.
  ///
  /// Cleared once it has played: without this the same folder would spring
  /// again on every rebuild of the list, which is the "constantly bouncing"
  /// failure mode this whole feature is trying to avoid.
  int? _justCreated;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<List<TripSummary>>(
      stream: scope.trips.watchTripSummaries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final trips = snapshot.data ?? const <TripSummary>[];

        if (trips.isEmpty) {
          return NookEmptyState(
            icon: Icons.folder_outlined,
            title: 'No trips yet — save your first find',
            message:
                'Trips are made when you save a post. Paste a link to '
                'start your first one.',
            actionLabel: 'Save First Find',
            onAction: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddMethodScreen())),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = NookSpacing.section;
            final width = (constraints.maxWidth - gap) / 2;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: NookSpacing.tight,
                bottom: NookSpacing.screenEdge,
              ),
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final summary in trips)
                    SizedBox(
                      width: width,
                      child: _maybeSpring(
                        summary.trip.id,
                        TripCard(
                          summary: summary,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TripDetailsScreen(tripId: summary.trip.id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: width,
                    child: _NewTripTile(
                      onTap: () async {
                        final draft = await showTripDialog(context);
                        if (draft == null || !context.mounted) return;
                        final user = await scope.users.currentUser();
                        if (user == null) return;
                        final id = await scope.trips.createTrip(
                          draft.name,
                          user.id,
                          colour: draft.colour,
                        );
                        if (!context.mounted) return;
                        setState(() => _justCreated = id);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Wraps exactly one card — the one just created — in a spring.
  ///
  /// The flag is deliberately *not* cleared afterwards. An earlier version
  /// cleared it in a post-frame callback, which pulled [FolderArrive] out of
  /// the tree on the very next frame and disposed its controller before any of
  /// the 340ms had run: the spring never played at all.
  ///
  /// Nothing needs clearing, because the key is what stops it repeating. The
  /// stream behind this list ticks on every write, but a stable key keeps the
  /// same State — and therefore the same already-finished controller — so the
  /// animation cannot restart. It ends at scale 1, which is exactly the plain
  /// card, and is replaced the next time a trip is created.
  Widget _maybeSpring(int tripId, Widget card) {
    if (tripId != _justCreated) return card;
    return FolderArrive(key: ValueKey('arrive-$tripId'), child: card);
  }
}

class _NewTripTile extends StatelessWidget {
  const _NewTripTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NookRadius.md),
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NookRadius.md),
          border: Border.all(color: NookColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_rounded, color: NookColors.primary),
            const SizedBox(width: NookSpacing.tight),
            Flexible(
              child: Text(
                'New Trip',
                style: NookType.bodyStrong.copyWith(color: NookColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
