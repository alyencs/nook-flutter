import 'package:flutter/material.dart';

import '../../explore/explore_catalogue.dart';
import '../../explore/explore_itinerary.dart';
import '../../theme/nook_spacing.dart';
import '../../widgets/entrance.dart';
import '../../widgets/explore_itinerary_card.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_empty_state.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/screen_title.dart';
import 'explore_itinerary_details_screen.dart';

/// Itineraries to borrow, rather than only the ones you have made yourself.
///
/// The catalogue is bundled, so there is nothing to wait for and no request to
/// fail: this screen is a list, and an empty state for the case where there is
/// genuinely nothing to show.
class ExploreItinerariesScreen extends StatelessWidget {
  const ExploreItinerariesScreen({super.key, this.country});

  /// Opened from a saved post, this is that post's country, so the list starts
  /// on the place the person was already reading about. Null browses all of it.
  final String? country;

  /// The catalogue, narrowed to [country] when that turns anything up.
  ///
  /// A country Nook has nothing for falls back to the whole list rather than
  /// an empty screen: the tap asked to explore, not to be told no.
  List<ExploreItinerary> get _matching {
    final filter = country?.trim().toLowerCase();
    if (filter == null || filter.isEmpty) return exploreItineraries;

    final matches = exploreItineraries
        .where((itinerary) => itinerary.country.toLowerCase() == filter)
        .toList(growable: false);
    return matches.isEmpty ? exploreItineraries : matches;
  }

  @override
  Widget build(BuildContext context) {
    final itineraries = _matching;
    final narrowed = itineraries.length != exploreItineraries.length;

    return NookScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NookAppBar(title: 'Explore Itineraries'),
          const SizedBox(height: NookSpacing.section),
          ScreenTitle(
            narrowed ? 'Itineraries in $country' : 'Itineraries to borrow',
          ),
          const SizedBox(height: NookSpacing.block),
          Expanded(
            child: itineraries.isEmpty
                ? const NookEmptyState(
                    icon: Icons.explore_outlined,
                    title: 'Nothing to explore yet',
                    message: 'Itineraries will appear here as they are added.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(
                      bottom: NookSpacing.screenEdge,
                    ),
                    itemCount: itineraries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: NookSpacing.section),
                    itemBuilder: (context, index) {
                      final itinerary = itineraries[index];
                      return Entrance(
                        index: index,
                        child: ExploreItineraryCard(
                          itinerary: itinerary,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExploreItineraryDetailsScreen(
                                itinerary: itinerary,
                              ),
                            ),
                          ),
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
