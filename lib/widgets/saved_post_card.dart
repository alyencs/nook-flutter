import 'package:flutter/material.dart';

import '../data/database.dart';
import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'metadata_chip.dart';
import 'platform_badge.dart';
import 'nook_card.dart';
import 'post_thumbnail.dart';

/// The Recent Saves carousel card: thumbnail on top, then title, creator and
/// the platform chip.
class SavedPostGridCard extends StatelessWidget {
  const SavedPostGridCard({super.key, required this.post, this.onTap});

  static const cardWidth = 150.0;

  final SavedPost post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      child: NookCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9, matching the thumbnails themselves. A squarer box crops a
            // 16:9 image down its sides and keeps the letterboxing it arrived
            // with, which puts black bars on every card.
            PostThumbnail(url: post.thumbnailUrl, aspectRatio: 16 / 9),
            const SizedBox(height: NookSpacing.tight),
            Text(
              post.title,
              style: NookType.bodyStrong,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              // A note has no creator; its destination, or nothing, reads
              // better there than a stray em dash.
              post.creator ?? post.aiDestination ?? '',
              style: NookType.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: NookSpacing.tight),
            PlatformChip(post.platform),
          ],
        ),
      ),
    );
  }
}

/// The list row used by Recently Viewed, Search and Trip Details.
///
/// [showDestination] swaps the creator line for the detected destination, which
/// is what the Search Results screen draws.
class SavedPostRowCard extends StatelessWidget {
  const SavedPostRowCard({
    super.key,
    required this.post,
    this.onTap,
    this.showDestination = false,
    this.showCategory = false,
  });

  final SavedPost post;
  final VoidCallback? onTap;
  final bool showDestination;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    // Search Results caption with the destination, everywhere else with the
    // creator. An em dash would only take room from the chips, so a post with
    // neither simply drops the caption and its separator.
    final caption =
        (showDestination ? post.aiDestination : post.creator)?.trim() ?? '';

    return NookCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PostThumbnail(
            url: post.thumbnailUrl,
            width: 64,
            height: 64,
            showGlyph: false,
          ),
          const SizedBox(width: NookSpacing.section),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post.title,
                  style: NookType.bodyStrong,
                  // One line, always: a title that wraps makes the list lurch
                  // as you scroll past long ones.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // A Row, not a Wrap: creator, platform and category stay on one
                // line, and the creator yields first because it is the part
                // that can be shortened without losing meaning.
                Row(
                  children: [
                    if (caption.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NookType.caption,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: NookSpacing.tight,
                        ),
                        child: Text(
                          '•',
                          style: TextStyle(color: NookColors.textMuted),
                        ),
                      ),
                    ],
                    PlatformChip(post.platform),
                    if (showCategory && post.aiCategory != null) ...[
                      const SizedBox(width: NookSpacing.tight),
                      MetadataChip(post.aiCategory!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
