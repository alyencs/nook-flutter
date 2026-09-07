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
import '../../widgets/trip_card.dart';
import '../add/add_method_screen.dart';
import 'trip_details_screen.dart';

/// The Trips tab.
///
/// The mockup never drew this screen, but the tab bar has a Trips tab and MVP
/// feature #3 needs somewhere to browse them. Built from the same cards, grid
/// and spacing as everything else — see decision 4 in docs/07-build-plan.md.
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
            child: Text('Your Trips', style: NookType.display),
          ),
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

class TripsBody extends StatelessWidget {
  const TripsBody({super.key});

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
            message: 'Trips are made when you save a post. Paste a link to '
                'start your first one.',
            actionLabel: 'Save First Find',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddMethodScreen()),
            ),
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
                      child: TripCard(
                        summary: summary,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TripDetailsScreen(tripId: summary.trip.id),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: width,
                    child: _NewTripTile(
                      onTap: () async {
                        final name = await showCreateTripDialog(context);
                        if (name == null || !context.mounted) return;
                        final user = await scope.users.currentUser();
                        if (user == null) return;
                        await scope.trips.createTrip(name, user.id);
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
