import 'package:flutter/material.dart';

import '../data/daos/trips_dao.dart';
import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'nook_card.dart';

/// A trip and how many posts are in it.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.summary, this.onTap});

  final TripSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NookCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const TripFolderTile(size: 34),
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
                  style: NookType.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The folder glyph in its pale rounded tile, reused wherever a trip is named.
class TripFolderTile extends StatelessWidget {
  const TripFolderTile({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: NookColors.placeholder,
        borderRadius: BorderRadius.circular(NookRadius.sm),
      ),
      child: Icon(
        Icons.folder_outlined,
        size: size * 0.5,
        color: NookColors.textPrimary,
      ),
    );
  }
}
