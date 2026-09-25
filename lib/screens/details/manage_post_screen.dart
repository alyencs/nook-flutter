import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/daos/trips_dao.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/delete_flight.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_toast.dart';
import '../../widgets/post_thumbnail.dart';
import '../../widgets/nook_rule.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/section_header.dart';
import '../../widgets/trip_card.dart';

/// S4. Move a post between trips, or delete it.
class ManagePostScreen extends StatefulWidget {
  const ManagePostScreen({super.key, required this.postId});

  final int postId;

  @override
  State<ManagePostScreen> createState() => _ManagePostScreenState();
}

class _ManagePostScreenState extends State<ManagePostScreen> {
  int? _selected;
  bool _loaded = false;

  /// The thumbnail in the header, so the delete flight knows where to start.
  final _thumbKey = GlobalKey();

  Future<void> _save() async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final navigator = Navigator.of(context);

    await AppScope.of(context).posts.moveToTrip(widget.postId, _selected);
    if (!mounted) return;
    navigator.pop();
    showToastAfterPop(overlay, 'Post moved');
  }

  Future<void> _delete() async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final navigator = Navigator.of(context);
    final posts = AppScope.of(context).posts;

    final confirmed = await showNookDialog(
      context,
      title: 'Delete this post?',
      message:
          'It moves to Recently Deleted, where you can restore it — '
          'including its note and its trip.',
      confirmLabel: 'Delete Post',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    // Read while the card is still on screen, before anything pops.
    final thumbnail = _thumbnailUrl;
    final box = _thumbKey.currentContext?.findRenderObject() as RenderBox?;
    final from = box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    // Back past the detail screen too: the post it was showing is gone.
    navigator
      ..pop()
      ..pop();

    // The card leaves for Profile — where Recently Deleted lives — and only
    // then is the row marked, so the two read as cause and effect rather than
    // the list twitching under a card that is still sitting there.
    //
    // Wrapped, because a delete that depends on an animation finishing is a
    // delete that can be lost. If the flight throws, the write still happens.
    if (from != null) {
      try {
        await DeleteFlight.run(overlay, from: from, thumbnailUrl: thumbnail);
      } catch (_) {
        // The post still has to go.
      }
    }

    await posts.deletePost(widget.postId);
    NookToast.show(
      overlay,
      'Moved to Recently Deleted',
      icon: Icons.restore_from_trash_outlined,
    );
  }

  /// Captured on each build so `_delete` can read it after the route has gone.
  String? _thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<SavedPost?>(
      stream: scope.posts.watchPost(widget.postId),
      builder: (context, postSnapshot) {
        final post = postSnapshot.data;
        if (post == null) return const NookScaffold(child: SizedBox.shrink());

        if (!_loaded) {
          _selected = post.tripId;
          _loaded = true;
        }
        _thumbnailUrl = post.thumbnailUrl;

        return StreamBuilder<List<TripSummary>>(
          stream: scope.trips.watchTripSummaries(),
          builder: (context, tripSnapshot) {
            final trips = tripSnapshot.data ?? const <TripSummary>[];
            final current = trips
                .where((t) => t.trip.id == _selected)
                .firstOrNull;
            final others = trips.where((t) => t.trip.id != _selected);

            return NookScaffold(
              bottomBar: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OverlineLabel('Actions'),
                  const SizedBox(height: NookSpacing.tight),
                  NookPrimaryButton(
                    label: 'Save Changes',
                    onPressed: _selected == post.tripId ? null : _save,
                  ),
                  const SizedBox(height: NookSpacing.tight),
                  NookSecondaryButton(
                    label: 'Delete Post',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    onPressed: _delete,
                  ),
                ],
              ),
              child: ListView(
                children: [
                  const NookAppBar(title: 'Manage Post'),
                  const SizedBox(height: NookSpacing.section),
                  // Which post this is about. The screen used to open straight
                  // onto a trip picker with nothing naming the post being
                  // moved — and it is also where the delete animation starts
                  // from, so the card you are looking at is the one that flies.
                  Row(
                    children: [
                      PostThumbnail(
                        key: _thumbKey,
                        url: post.thumbnailUrl,
                        width: 56,
                        height: 56,
                        showGlyph: false,
                      ),
                      const SizedBox(width: NookSpacing.section),
                      Expanded(
                        child: Text(
                          post.title,
                          style: NookType.bodyStrong,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NookSpacing.block),
                  // The label's own trailing slot, not a Row around it: a
                  // RuledLabel stretches its rule with an Expanded, which needs
                  // a bounded width, and a Row gives its children unbounded.
                  RuledLabel(
                    'Current trip',
                    trailing: _selected == null
                        ? null
                        : InkWell(
                            onTap: () => setState(() => _selected = null),
                            child: Text(
                              'Remove',
                              style: NookType.body.copyWith(
                                color: NookColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: NookSpacing.tight),
                  Container(
                    padding: const EdgeInsets.all(NookSpacing.section),
                    decoration: BoxDecoration(
                      color: NookColors.surface,
                      borderRadius: BorderRadius.circular(NookRadius.md),
                      border: Border.all(
                        color: NookColors.textPrimary,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_outlined, size: 22),
                        const SizedBox(width: NookSpacing.tight),
                        Expanded(
                          child: Text(
                            current?.trip.name ?? 'No trip',
                            style: NookType.bodyStrong,
                          ),
                        ),
                        if (current != null)
                          const Icon(Icons.check_rounded, size: 22),
                      ],
                    ),
                  ),
                  const SizedBox(height: NookSpacing.block),
                  const OverlineLabel('Move to another trip'),
                  const SizedBox(height: NookSpacing.tight),
                  for (final summary in others) ...[
                    InkWell(
                      onTap: () => setState(() => _selected = summary.trip.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: NookSpacing.tight,
                        ),
                        child: Row(
                          children: [
                            const TripFolderTile(size: 32),
                            const SizedBox(width: NookSpacing.section),
                            Expanded(
                              child: Text(
                                summary.trip.name,
                                style: NookType.body,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: NookColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
