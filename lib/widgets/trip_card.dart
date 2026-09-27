import 'package:flutter/material.dart';

import '../data/daos/trips_dao.dart';
import '../theme/nook_colors.dart';
import '../theme/trip_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'folder_motion.dart';
import 'nook_card.dart';

/// A trip and how many posts are in it.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.summary, this.onTap});

  final TripSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = NookCard(
      // `onTap` moves to FolderOpen, which runs it once the lid has lifted.
      // Leaving it here as well would fire the navigation twice.
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          TripFolderTile(size: 34, colour: summary.colour),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.trip.name,
                  style: NookType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.itemCount} ${summary.itemCount == 1 ? 'item' : 'items'}',
                  style: NookType.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // A card with nowhere to go does not open. Choose-a-trip lists pass no
    // callback, and a folder that tips for nothing is a lie.
    if (onTap == null) return card;
    return FolderOpen(onTap: onTap!, child: card);
  }
}

/// The folder glyph in its rounded tile, reused wherever a trip is named.
///
/// The colour is the trip's own, so four trips are four folders rather than
/// four identical grey squares — which is the whole point of letting someone
/// choose one.
class TripFolderTile extends StatelessWidget {
  const TripFolderTile({super.key, this.size = 44, this.colour});

  final double size;

  /// Null keeps the old neutral tile, for the places that name no trip.
  final TripColor? colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colour?.fill ?? NookColors.placeholder,
        borderRadius: BorderRadius.circular(NookRadius.sm),
        border: colour == null ? null : Border.all(color: colour!.edge),
      ),
      child: Icon(
        Icons.folder_rounded,
        size: size * 0.5,
        color: colour?.ink ?? NookColors.textPrimary,
      ),
    );
  }
}
