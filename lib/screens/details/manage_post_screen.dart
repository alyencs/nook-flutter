import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/daos/trips_dao.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_dialog.dart';
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

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await AppScope.of(context).posts.moveToTrip(widget.postId, _selected);
    if (!mounted) return;
    navigator.pop();
    await showSnackBarAfterPop(messenger, 'Post moved');
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final posts = AppScope.of(context).posts;

    final confirmed = await showNookDialog(
      context,
      title: 'Delete this post?',
      message: 'It will be removed from your library and from its trip. This '
          'cannot be undone.',
      confirmLabel: 'Delete Post',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await posts.deletePost(widget.postId);
    if (!mounted) return;
    // Back past the detail screen too: the post it was showing is gone.
    navigator
      ..pop()
      ..pop();
    await showSnackBarAfterPop(messenger, 'Post deleted');
  }

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

        return StreamBuilder<List<TripSummary>>(
          stream: scope.trips.watchTripSummaries(),
          builder: (context, tripSnapshot) {
            final trips = tripSnapshot.data ?? const <TripSummary>[];
            final current = trips.where((t) => t.trip.id == _selected).firstOrNull;
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const OverlineLabel('Current trip'),
                      if (_selected != null)
                        InkWell(
                          onTap: () => setState(() => _selected = null),
                          child: Text(
                            'Remove',
                            style: NookType.body.copyWith(
                              color: NookColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
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
                  const SizedBox(height: NookSpacing.screenEdge),
                  const OverlineLabel('Move to another trip'),
                  const SizedBox(height: NookSpacing.tight),
                  for (final summary in others) ...[
                    InkWell(
                      onTap: () => setState(() => _selected = summary.trip.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: NookSpacing.section,
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
