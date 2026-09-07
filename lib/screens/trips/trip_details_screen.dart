import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_empty_state.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/saved_post_card.dart';
import '../../widgets/trip_card.dart';
import '../details/post_details_screen.dart';

/// One trip and everything saved into it.
///
/// Not drawn in the mockup either; built from the same row cards the rest of
/// the app uses. Rename and delete live behind the "…" action rather than
/// cluttering the header.
class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<Trip?>(
      stream: scope.trips.watchTrip(tripId),
      builder: (context, tripSnapshot) {
        final trip = tripSnapshot.data;
        if (trip == null) return const NookScaffold(child: SizedBox.shrink());

        return NookScaffold(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NookAppBar(
                title: trip.name,
                action: NookSquareAction(
                  icon: Icons.more_horiz_rounded,
                  semanticLabel: 'Trip options',
                  onTap: () => _showOptions(context, trip),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<SavedPost>>(
                  stream: scope.posts.watchByTrip(tripId),
                  builder: (context, snapshot) {
                    final posts = snapshot.data ?? const <SavedPost>[];
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    if (posts.isEmpty) {
                      return const NookEmptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'Nothing saved here yet',
                        message: 'Posts you add to this trip will show up here.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(
                        top: NookSpacing.tight,
                        bottom: NookSpacing.screenEdge,
                      ),
                      itemCount: posts.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: NookSpacing.section),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Row(
                            children: [
                              const TripFolderTile(size: 36),
                              const SizedBox(width: NookSpacing.tight),
                              Text(
                                '${posts.length} '
                                '${posts.length == 1 ? 'saved post' : 'saved posts'}',
                                style: NookType.caption.copyWith(fontSize: 14),
                              ),
                            ],
                          );
                        }
                        final post = posts[index - 1];
                        return SavedPostRowCard(
                          post: post,
                          onTap: () => openPostDetails(context, post.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showOptions(BuildContext context, Trip trip) async {
    final scope = AppScope.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NookColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NookRadius.md)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('Rename trip', style: NookType.body),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final name = await showCreateTripDialog(context);
                if (name == null) return;
                await scope.trips.rename(trip.id, name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: NookColors.error),
              title: Text(
                'Delete trip',
                style: NookType.body.copyWith(color: NookColors.error),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await showNookDialog(
                  context,
                  title: 'Delete this trip?',
                  message: 'The posts saved in it are kept — they just stop '
                      'belonging to a trip.',
                  confirmLabel: 'Delete Trip',
                  destructive: true,
                );
                if (!confirmed || !context.mounted) return;
                await scope.trips.deleteTrip(trip.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
