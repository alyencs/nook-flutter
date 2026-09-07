import 'package:flutter/material.dart';

import '../ai/platform_from_url.dart';
import '../data/database.dart';
import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'metadata_chip.dart';
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
            PostThumbnail(url: post.thumbnailUrl, aspectRatio: 1.25),
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
              style: NookType.caption.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: NookSpacing.tight),
            MetadataChip(NookPlatform.label(post.platform)),
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
            height: 56,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // A Row, not a Wrap: the mockup keeps the creator, the
                // platform and the category on one line. In a Wrap the chips
                // dropped underneath the creator as soon as the text was long.
                // Here the creator yields instead — it is the part that can be
                // shortened without losing meaning.
                Row(
                  children: [
                    if (caption.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NookType.caption.copyWith(fontSize: 13),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: NookSpacing.tight,
                        ),
                        child: Text(
                          '•',
                          style: TextStyle(
                            color: NookColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    MetadataChip(NookPlatform.label(post.platform)),
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
