import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/entrance.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_empty_state.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_toast.dart';
import '../../widgets/post_thumbnail.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/section_header.dart';

/// Where deleted posts and trips wait.
///
/// Deleting has always been one tap behind a confirmation, and a confirmation
/// is a poor safety net: it asks before you know you were wrong. This is the
/// net — nothing is destroyed at the point of deleting, only marked, and the
/// row keeps everything it needs to come back: a post's note, its extraction
/// and its trip; a trip's identity, so its posts find their way home.
class RecentlyDeletedScreen extends StatefulWidget {
  const RecentlyDeletedScreen({super.key});

  /// How long something stays here before it is dropped for good.
  static const retention = Duration(days: 30);

  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen> {
  bool _purged = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Opening the screen is the only moment the retention window can have
    // elapsed without the app running, so it is the only moment worth checking.
    if (_purged) return;
    _purged = true;
    final scope = AppScope.of(context);
    final cutoff = DateTime.now().subtract(RecentlyDeletedScreen.retention);
    scope.posts.purgeDeletedBefore(cutoff);
    scope.trips.purgeDeletedBefore(cutoff);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return NookScaffold(
      child: StreamBuilder<List<SavedPost>>(
        stream: scope.posts.watchDeleted(),
        builder: (context, postSnapshot) {
          return StreamBuilder<List<Trip>>(
            stream: scope.trips.watchDeleted(),
            builder: (context, tripSnapshot) {
              final posts = postSnapshot.data ?? const <SavedPost>[];
              final trips = tripSnapshot.data ?? const <Trip>[];
              final empty = posts.isEmpty && trips.isEmpty;

              return ListView(
                children: [
                  NookAppBar(
                    title: 'Recently Deleted',
                    action: empty
                        ? null
                        : _EmptyAction(onTap: () => _confirmEmptyAll(context)),
                  ),
                  const SizedBox(height: NookSpacing.section),
                  const ScreenTitle('Recently Deleted'),
                  const SizedBox(height: NookSpacing.tight),
                  Text(
                    'Items stay here for 30 days. Restoring puts something '
                    'back exactly where it was.',
                    style: NookType.body.copyWith(color: NookColors.textMuted),
                  ),
                  const SizedBox(height: NookSpacing.block),

                  if (empty)
                    const Padding(
                      padding: EdgeInsets.only(top: NookSpacing.block),
                      child: NookEmptyState(
                        icon: Icons.restore_from_trash_outlined,
                        title: 'Nothing deleted',
                        message:
                            'Posts and trips you delete will wait here before '
                            'they go for good.',
                      ),
                    ),

                  if (trips.isNotEmpty) ...[
                    const SectionHeader('Trips'),
                    const SizedBox(height: NookSpacing.tight),
                    for (final (index, trip) in trips.indexed)
                      Entrance(
                        key: ValueKey('trip-${trip.id}'),
                        index: index,
                        child: _DeletedTripRow(trip: trip),
                      ),
                    const SizedBox(height: NookSpacing.block),
                  ],

                  if (posts.isNotEmpty) ...[
                    const SectionHeader('Posts'),
                    const SizedBox(height: NookSpacing.tight),
                    for (final (index, post) in posts.indexed)
                      Entrance(
                        key: ValueKey('post-${post.id}'),
                        // Continues the count from the trips above, so the two
                        // lists arrive as one sequence rather than two.
                        index: trips.length + index,
                        child: _DeletedPostRow(post: post),
                      ),
                  ],

                  const SizedBox(height: NookSpacing.block),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmEmptyAll(BuildContext context) async {
    final scope = AppScope.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);

    final confirmed = await showNookDialog(
      context,
      title: 'Delete everything here?',
      message:
          'Everything in Recently Deleted goes for good. Posts restored '
          'to your library are not affected.',
      confirmLabel: 'Delete All',
      destructive: true,
    );
    if (!confirmed) return;

    await scope.posts.emptyDeleted();
    await scope.trips.emptyDeleted();
    NookToast.show(overlay, 'Recently Deleted is empty');
  }
}

class _EmptyAction extends StatelessWidget {
  const _EmptyAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        'Empty',
        style: NookType.bodyStrong.copyWith(color: NookColors.error),
      ),
    );
  }
}

/// One deleted post: what it was, and the two ways out.
class _DeletedPostRow extends StatelessWidget {
  const _DeletedPostRow({required this.post});

  final SavedPost post;

  @override
  Widget build(BuildContext context) {
    return _DeletedRow(
      leading: PostThumbnail(
        url: post.thumbnailUrl,
        width: 48,
        height: 48,
        showGlyph: false,
      ),
      title: post.title,
      subtitle: _deletedAgo(post.deletedAt),
      onRestore: () async {
        final scope = AppScope.of(context);
        final overlay = Overlay.of(context, rootOverlay: true);
        await scope.posts.restorePost(post.id);
        NookToast.show(overlay, 'Restored "${post.title}"');
      },
      onDeleteForever: () async {
        final scope = AppScope.of(context);
        final overlay = Overlay.of(context, rootOverlay: true);
        final confirmed = await showNookDialog(
          context,
          title: 'Delete permanently?',
          message: '"${post.title}" and its note will be gone for good.',
          confirmLabel: 'Delete Permanently',
          destructive: true,
        );
        if (!confirmed) return;
        await scope.posts.deletePostForever(post.id);
        NookToast.show(overlay, 'Deleted permanently');
      },
    );
  }
}

/// One deleted trip. The subtitle counts the posts that are still pointing at
/// it — the ones that would reappear inside it on restore.
class _DeletedTripRow extends StatelessWidget {
  const _DeletedTripRow({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return FutureBuilder<int>(
      future: scope.trips.postsAwaiting(trip.id),
      builder: (context, snapshot) {
        final waiting = snapshot.data;
        return _DeletedRow(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: NookColors.placeholder,
              borderRadius: BorderRadius.circular(NookRadius.sm),
            ),
            child: const Icon(
              Icons.folder_outlined,
              size: 22,
              color: NookColors.textMuted,
            ),
          ),
          title: trip.name,
          subtitle: [
            _deletedAgo(trip.deletedAt),
            if (waiting != null && waiting > 0)
              '$waiting post${waiting == 1 ? '' : 's'} will return to it',
          ].join(' · '),
          onRestore: () async {
            final overlay = Overlay.of(context, rootOverlay: true);
            await scope.trips.restoreTrip(trip.id);
            NookToast.show(overlay, 'Restored "${trip.name}"');
          },
          onDeleteForever: () async {
            final overlay = Overlay.of(context, rootOverlay: true);
            final confirmed = await showNookDialog(
              context,
              title: 'Delete this trip permanently?',
              message: waiting != null && waiting > 0
                  ? 'The $waiting post${waiting == 1 ? '' : 's'} in it will '
                        'still be kept — they simply stop belonging to a trip.'
                  : 'The trip will be gone for good.',
              confirmLabel: 'Delete Permanently',
              destructive: true,
            );
            if (!confirmed) return;
            await scope.trips.deleteTripForever(trip.id);
            NookToast.show(overlay, 'Deleted permanently');
          },
        );
      },
    );
  }
}

/// The shared shape, so a deleted trip and a deleted post read as one list.
class _DeletedRow extends StatelessWidget {
  const _DeletedRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Future<void> Function() onRestore;
  final Future<void> Function() onDeleteForever;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NookSpacing.tight),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(NookRadius.sm),
            child: leading,
          ),
          const SizedBox(width: NookSpacing.section),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NookType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: NookType.caption.copyWith(color: NookColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: NookSpacing.tight),
          // The safe action reads as the default; the irreversible one is set
          // apart in the error colour rather than sitting next to it as an
          // equal.
          IconButton(
            onPressed: onRestore,
            icon: const Icon(Icons.restore_rounded, size: 21),
            color: NookColors.primary,
            tooltip: 'Restore',
          ),
          IconButton(
            onPressed: onDeleteForever,
            icon: const Icon(Icons.delete_forever_outlined, size: 21),
            color: NookColors.error,
            tooltip: 'Delete permanently',
          ),
        ],
      ),
    );
  }
}

/// "Deleted today", "Deleted 3 days ago" — and, near the end, how long is left.
String _deletedAgo(DateTime? when) {
  if (when == null) return 'Deleted';
  final days = DateTime.now().difference(when).inDays;
  final left = RecentlyDeletedScreen.retention.inDays - days;
  if (left <= 3 && left > 0) {
    return left == 1 ? 'Removed tomorrow' : 'Removed in $left days';
  }
  if (days <= 0) return 'Deleted today';
  if (days == 1) return 'Deleted yesterday';
  return 'Deleted $days days ago';
}
