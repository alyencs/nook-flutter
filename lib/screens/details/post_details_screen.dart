import 'package:flutter/material.dart';

import '../../ai/source_metadata.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../util/nook_date.dart';
import '../../widgets/metadata_chip.dart';
import '../../widgets/platform_badge.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/section_header.dart';
import '../../widgets/post_thumbnail.dart';
import 'manage_post_screen.dart';
import 'personal_notes_screen.dart';
import 'travel_details_screen.dart';

/// Opens a post and records that it was opened, which is what fills the
/// "Recently Viewed" section on Home.
void openPostDetails(BuildContext context, int postId) {
  AppScope.of(context).posts.markViewed(postId);
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PostDetailsScreen(postId: postId)),
  );
}

/// S1.
class PostDetailsScreen extends StatelessWidget {
  const PostDetailsScreen({super.key, required this.postId});

  final int postId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<SavedPost?>(
      stream: scope.posts.watchPost(postId),
      builder: (context, snapshot) {
        final post = snapshot.data;
        if (post == null) return const NookScaffold(child: SizedBox.shrink());

        return NookScaffold(
          bottomBar: Row(
            children: [
              Expanded(
                child: NookPrimaryButton(
                  // The mockup labels this "Continue", which says nothing on a
                  // detail screen — and Travel Details would otherwise have no
                  // way in. See decision 9 in docs/07-build-plan.md.
                  label: 'Travel Details',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TravelDetailsScreen(postId: post.id),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: NookSpacing.tight),
              NookSquareAction(
                icon: Icons.ios_share_rounded,
                semanticLabel: 'Share',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sharing is not in this build.')),
                ),
              ),
            ],
          ),
          child: ListView(
            children: [
              NookAppBar(
                title: 'Post Details',
                action: NookSquareAction(
                  icon: Icons.more_horiz_rounded,
                  semanticLabel: 'Manage post',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ManagePostScreen(postId: post.id),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NookSpacing.section),
              Stack(
                children: [
                  PostThumbnail(
                    url: post.thumbnailUrl,
                    // 16:9, the shape the thumbnails themselves are, so the
                    // image fills the box instead of being letterboxed into it.
                    aspectRatio: 16 / 9,
                    showGlyph: false,
                    radius: NookRadius.md,
                  ),
                  Positioned(
                    top: NookSpacing.tight,
                    left: NookSpacing.tight,
                    // What this actually is, not what every post was assumed to
                    // be. A photo post is not a video.
                    child: MetadataChip(_mediaLabel(post)),
                  ),
                ],
              ),
              const SizedBox(height: NookSpacing.block),
              Text(post.title, style: NookType.heading),
              if (post.creator != null) ...[
                const SizedBox(height: NookSpacing.section),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: NookColors.placeholder,
                        shape: BoxShape.circle,
                        border: Border.all(color: NookColors.border),
                      ),
                    ),
                    const SizedBox(width: NookSpacing.tight),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.creator!,
                            style: NookType.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (post.creatorHandle != null)
                            Text(
                              post.creatorHandle!,
                              style: NookType.caption
                                  .copyWith(color: NookColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: NookSpacing.section),
              Text(
                post.aiDestination ?? '—',
                style: NookType.body.copyWith(color: NookColors.textMuted),
              ),
              const SizedBox(height: NookSpacing.section),
              Wrap(
                spacing: NookSpacing.tight,
                runSpacing: NookSpacing.tight,
                children: [
                  PlatformChip(post.platform),
                  if (post.aiCategory != null)
                    MetadataChip(post.aiCategory!, icon: Icons.sell_outlined),
                ],
              ),
              if (post.caption != null) ...[
                const SizedBox(height: NookSpacing.block),
                const OverlineLabel('Caption'),
                const SizedBox(height: NookSpacing.tight),
                Text(post.caption!, style: NookType.body),
              ],
              if (post.aiSummary != null) ...[
                const SizedBox(height: NookSpacing.block),
                const OverlineLabel('AI summary'),
                const SizedBox(height: NookSpacing.tight),
                Text(post.aiSummary!, style: NookType.body),
              ],
              const SizedBox(height: NookSpacing.block),
              const OverlineLabel('Trip'),
              const SizedBox(height: NookSpacing.tight),
              _TripTile(tripId: post.tripId),
              const SizedBox(height: NookSpacing.block),
              const OverlineLabel('Personal notes'),
              const SizedBox(height: NookSpacing.tight),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PersonalNotesScreen(postId: post.id),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    post.personalNote ?? 'Add a note',
                    style: NookType.body.copyWith(
                      color: post.personalNote == null
                          ? NookColors.textMuted
                          : NookColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NookSpacing.block),
              // One rich string rather than two Texts in a Row: the date can
              // be long, and a Row would clip it rather than wrap.
              Text.rich(
                TextSpan(
                  style: NookType.body.copyWith(color: NookColors.textMuted),
                  children: [
                    const TextSpan(text: 'Saved on '),
                    TextSpan(
                      text: formatLongDate(post.dateSaved),
                      style: NookType.bodyStrong,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NookSpacing.section),
            ],
          ),
        );
      },
    );
  }
}

/// What the badge over the preview says.
///
/// Read from the stored media type rather than assumed. Posts saved before
/// that column existed have no value, so they fall back to the neutral
/// "Preview" instead of claiming to be a video.
String _mediaLabel(SavedPost post) {
  if (post.importMethod == 'note') return 'Note';
  return PostMediaType.parse(post.mediaType).label;
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.tripId});

  final int? tripId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Container(
      padding: const EdgeInsets.all(NookSpacing.section),
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(NookRadius.md),
        border: Border.all(color: NookColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 22),
          const SizedBox(width: NookSpacing.tight),
          if (tripId == null)
            Text(
              'No trip',
              style: NookType.body.copyWith(color: NookColors.textMuted),
            )
          else
            StreamBuilder<Trip?>(
              stream: scope.trips.watchTrip(tripId!),
              builder: (context, snapshot) => Text(
                snapshot.data?.name ?? '—',
                style: NookType.bodyStrong,
              ),
            ),
        ],
      ),
    );
  }
}
