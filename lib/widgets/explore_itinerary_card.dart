import 'package:flutter/material.dart';

import '../explore/explore_itinerary.dart';
import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'metadata_chip.dart';
import 'nook_card.dart';
import 'post_thumbnail.dart';

/// One itinerary in the Explore list.
///
/// The same card surface, 16:9 thumbnail and chips the saved-post cards use,
/// so something you have not saved yet still reads as part of the library
/// rather than as an advert for one.
class ExploreItineraryCard extends StatelessWidget {
  const ExploreItineraryCard({super.key, required this.itinerary, this.onTap});

  final ExploreItinerary itinerary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NookCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostThumbnail(
            url: itinerary.coverImage,
            aspectRatio: 16 / 9,
            showGlyph: false,
          ),
          const SizedBox(height: NookSpacing.tight),
          Text(
            itinerary.title,
            style: NookType.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            itinerary.destination,
            style: NookType.body.copyWith(color: NookColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: NookSpacing.tight),
          // Wrap rather than Row: three chips and a long country name will not
          // fit one line on the narrowest phone, and a chip row that overflows
          // is the bug this app has already fixed twice.
          Wrap(
            spacing: NookSpacing.tight,
            runSpacing: NookSpacing.tight,
            children: [
              MetadataChip(itinerary.durationLabel, icon: Icons.schedule_rounded),
              MetadataChip(itinerary.stopsLabel, icon: Icons.place_outlined),
              MetadataChip(itinerary.country),
            ],
          ),
        ],
      ),
    );
  }
}
