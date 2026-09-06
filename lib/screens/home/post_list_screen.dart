import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/nook_spacing.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_empty_state.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/saved_post_card.dart';
import '../details/post_details_screen.dart';

/// Where a "See All" goes: the same rows, without the section's cut-off.
class PostListScreen extends StatelessWidget {
  const PostListScreen({
    super.key,
    required this.title,
    required this.posts,
    this.emptyMessage = 'Nothing here yet.',
  });

  final String title;
  final Stream<List<SavedPost>> posts;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NookAppBar(title: title),
          Expanded(
            child: StreamBuilder<List<SavedPost>>(
              stream: posts,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <SavedPost>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (items.isEmpty) {
                  return NookEmptyState(
                    icon: Icons.bookmark_outline_rounded,
                    title: 'Nothing to show',
                    message: emptyMessage,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(
                    top: NookSpacing.tight,
                    bottom: NookSpacing.screenEdge,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: NookSpacing.section),
                  itemBuilder: (context, index) => SavedPostRowCard(
                    post: items[index],
                    onTap: () => openPostDetails(context, items[index].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
