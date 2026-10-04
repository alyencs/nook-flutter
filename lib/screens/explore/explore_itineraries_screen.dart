import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/daos/trips_dao.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/entrance.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_card.dart';
import '../../widgets/nook_empty_state.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/trip_card.dart';
import '../add/add_method_screen.dart';
import 'itinerary_plan_screen.dart';

/// Which trip to plan.
///
/// The trips are the destinations, because that is already how the library is
/// organised: a trip is a place and the posts saved into it are what is known
/// about it. Nothing here is a catalogue of somebody else's holidays — every
/// row is the traveller's own saved material, waiting to be turned into days.
class ExploreItinerariesScreen extends StatelessWidget {
  const ExploreItinerariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return NookScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NookAppBar(title: 'Explore Itinerary'),
          const SizedBox(height: NookSpacing.section),
          const ScreenTitle('Plan from what you saved'),
          const SizedBox(height: NookSpacing.tight),
          Text(
            'Pick a trip. Nook reads the posts in it and lays them out over '
            'however many days you have.',
            style: NookType.body.copyWith(
              color: NookColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: NookSpacing.block),
          Expanded(
            child: StreamBuilder<List<TripSummary>>(
              stream: scope.trips.watchTripSummaries(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }

                final trips = snapshot.data ?? const <TripSummary>[];
                // Trips with something in them first: a trip with no posts
                // cannot be planned yet, and it should not be the first thing
                // offered. It stays on the list so it is clear why.
                final ordered = [
                  ...trips.where((t) => t.itemCount > 0),
                  ...trips.where((t) => t.itemCount == 0),
                ];

                if (ordered.isEmpty) {
                  return NookEmptyState(
                    icon: Icons.near_me_outlined,
                    title: 'Nothing to plan from yet',
                    message:
                        'Save a few posts about somewhere you want to go, and '
                        'Nook can turn them into an itinerary.',
                    actionLabel: 'Save First Find',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddMethodScreen(),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                    bottom: NookSpacing.screenEdge,
                  ),
                  itemCount: ordered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: NookSpacing.section),
                  itemBuilder: (context, index) => Entrance(
                    index: index,
                    child: _TripRow(summary: ordered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One trip, with how much there is to plan from.
class _TripRow extends StatelessWidget {
  const _TripRow({required this.summary});

  final TripSummary summary;

  @override
  Widget build(BuildContext context) {
    final count = summary.itemCount;
    final plannable = count > 0;

    return NookCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItineraryPlanScreen(tripId: summary.trip.id),
        ),
      ),
      child: Row(
        children: [
          TripFolderTile(size: 44, colour: summary.colour),
          const SizedBox(width: NookSpacing.section),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.trip.name,
                  style: NookType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  plannable
                      ? '$count saved ${count == 1 ? 'post' : 'posts'} to '
                            'plan from'
                      : 'Nothing saved here yet',
                  style: NookType.caption.copyWith(
                    color: plannable
                        ? NookColors.textMuted
                        : NookColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: NookColors.textMuted,
          ),
        ],
      ),
    );
  }
}
