import 'package:flutter/material.dart';

import '../../ai/categories.dart';
import '../../app_scope.dart';
import '../../data/daos/settings_dao.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/metadata_chip.dart';
import '../../widgets/nook_empty_state.dart';
import '../../widgets/nook_text_field.dart';
import '../../widgets/saved_post_card.dart';
import '../add/add_method_screen.dart';
import '../details/post_details_screen.dart';

/// H5 and H6. Feature #4.
///
/// Lives inside the Home tab rather than on a route of its own — the mockup
/// names these frames "Home: Search" and "Home: Search Results", and draws the
/// tab bar on both. Two states: browse (recent searches, suggested categories,
/// everything saved) and results.
class SearchBody extends StatefulWidget {
  const SearchBody({super.key});

  @override
  State<SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<SearchBody> {
  final _query = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _run(String term) {
    setState(() => _term = term);
    _query.text = term;
    _query.selection = TextSelection.collapsed(offset: term.length);
    if (term.trim().length > 1) {
      AppScope.of(context).searches.record(term);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searching = _term.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: NookSpacing.section),
        NookSearchBar(
          controller: _query,
          autofocus: true,
          onChanged: (value) => setState(() => _term = value),
          onSubmitted: _run,
          onClear: () {
            _query.clear();
            setState(() => _term = '');
          },
        ),
        const SizedBox(height: NookSpacing.screenEdge),
        Expanded(
          child: searching ? _Results(term: _term) : _Browse(onPickTerm: _run),
        ),
      ],
    );
  }
}

/// H5.
class _Browse extends StatelessWidget {
  const _Browse({required this.onPickTerm});

  final ValueChanged<String> onPickTerm;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return ListView(
      children: [
        StreamBuilder<List<RecentSearch>>(
          stream: scope.searches.watchRecent(),
          builder: (context, snapshot) {
            final searches = snapshot.data ?? const <RecentSearch>[];
            if (searches.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent Searches', style: NookType.overline),
                const SizedBox(height: NookSpacing.tight),
                for (final search in searches)
                  _RecentSearchRow(
                    search: search,
                    onTap: () => onPickTerm(search.query),
                    onDelete: () => scope.searches.delete(search.id),
                  ),
                const SizedBox(height: NookSpacing.screenEdge),
              ],
            );
          },
        ),
        StreamBuilder<Map<String, bool>>(
          stream: scope.settings.watchAll(),
          builder: (context, snapshot) {
            final show = (snapshot.data ??
                NookSettings.defaults)[NookSettings.categorySuggestions]!;
            if (!show) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Suggested Categories', style: NookType.overline),
                const SizedBox(height: NookSpacing.section),
                Wrap(
                  spacing: NookSpacing.tight,
                  runSpacing: NookSpacing.tight,
                  children: [
                    for (final category in NookCategories.all)
                      InkWell(
                        onTap: () => onPickTerm(category),
                        borderRadius: BorderRadius.circular(NookRadius.pill),
                        child: MetadataChip.outlined(category),
                      ),
                  ],
                ),
                const SizedBox(height: NookSpacing.screenEdge),
              ],
            );
          },
        ),
        Text('All Saved Posts', style: NookType.overline),
        const SizedBox(height: NookSpacing.section),
        StreamBuilder<List<SavedPost>>(
          stream: scope.posts.watchAll(),
          builder: (context, snapshot) {
            final posts = snapshot.data ?? const <SavedPost>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            if (posts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 48),
                child: NookEmptyState(
                  icon: Icons.search_rounded,
                  title: 'Nothing saved yet',
                  message: 'Save your first find and it becomes searchable '
                      'straight away.',
                  actionLabel: 'Save First Find',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddMethodScreen()),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final post in posts) ...[
                  SavedPostRowCard(
                    post: post,
                    onTap: () => openPostDetails(context, post.id),
                  ),
                  const SizedBox(height: NookSpacing.section),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// H6. Destination replaces the creator line, and the category chip joins the
/// platform chip — the revision brief's one change to this screen.
class _Results extends StatelessWidget {
  const _Results({required this.term});

  final String term;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedPost>>(
      stream: AppScope.of(context).posts.search(term),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final results = snapshot.data ?? const <SavedPost>[];

        if (results.isEmpty) {
          return NookEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No results',
            message: 'Nothing saved matches "$term" yet.',
          );
        }

        return ListView.separated(
          itemCount: results.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: NookSpacing.section),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                '${results.length} ${results.length == 1 ? 'result' : 'results'}',
                style: NookType.overline.copyWith(fontSize: 13),
              );
            }
            final post = results[index - 1];
            return SavedPostRowCard(
              post: post,
              showDestination: true,
              showCategory: true,
              onTap: () => openPostDetails(context, post.id),
            );
          },
        );
      },
    );
  }
}

class _RecentSearchRow extends StatelessWidget {
  const _RecentSearchRow({
    required this.search,
    required this.onTap,
    required this.onDelete,
  });

  final RecentSearch search;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NookRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NookSpacing.tight),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 22,
              color: NookColors.textPrimary,
            ),
            const SizedBox(width: NookSpacing.section),
            Expanded(
              child: Text(
                search.query,
                style: NookType.body.copyWith(fontSize: 17),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.cancel, size: 22),
              color: NookColors.textMuted,
              tooltip: 'Remove "${search.query}"',
            ),
          ],
        ),
      ),
    );
  }
}
