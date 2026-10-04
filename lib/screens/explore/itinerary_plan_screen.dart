import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../explore/itinerary_context.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/metadata_chip.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_empty_state.dart';
import '../../widgets/nook_rule.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/post_thumbnail.dart';
import '../../widgets/screen_title.dart';
import '../add/add_method_screen.dart';
import 'itinerary_result_screen.dart';

/// What Nook is planning from, and how long the trip is.
///
/// The posts are shown before anything is generated on purpose: a plan built
/// from someone's own saved material should show its working, so it is obvious
/// where the days came from and obvious when there is not enough to go on.
class ItineraryPlanScreen extends StatefulWidget {
  const ItineraryPlanScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<ItineraryPlanScreen> createState() => _ItineraryPlanScreenState();
}

class _ItineraryPlanScreenState extends State<ItineraryPlanScreen> {
  /// Three is the default because it is the commonest short trip and the one
  /// the saved posts usually carry enough material for.
  int _days = 3;

  /// How many days the chooser offers. Matched to the generators' own ceiling.
  static const _choices = [1, 2, 3, 4, 5, 6, 7];

  /// True while the result route is being pushed, so two quick taps on
  /// Generate open one plan rather than stacking two of them.
  bool _opening = false;

  Future<void> _generate(String tripName, List<SavedPost> posts) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItineraryResultScreen(
            request: ItineraryContext.requestFor(
              tripName: tripName,
              posts: posts,
              days: _days,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<Trip?>(
      stream: scope.trips.watchTrip(widget.tripId),
      builder: (context, tripSnapshot) {
        final trip = tripSnapshot.data;
        if (trip == null) return const NookScaffold(child: SizedBox.shrink());

        return StreamBuilder<List<SavedPost>>(
          stream: scope.posts.watchByTrip(widget.tripId),
          builder: (context, postSnapshot) {
            if (postSnapshot.connectionState == ConnectionState.waiting) {
              return NookScaffold(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [NookAppBar(title: trip.name)],
                ),
              );
            }

            final posts = postSnapshot.data ?? const <SavedPost>[];
            final destination =
                ItineraryContext.destinationOf(posts) ?? trip.name;
            final usable = ItineraryContext.usableCount(posts);

            if (posts.isEmpty) {
              return NookScaffold(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NookAppBar(title: trip.name),
                    Expanded(
                      child: NookEmptyState(
                        icon: Icons.near_me_outlined,
                        title: 'Nothing saved to this trip yet',
                        message:
                            'Save a few posts about ${trip.name} and Nook can '
                            'plan the days around them.',
                        actionLabel: 'Save a Post',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddMethodScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return NookScaffold(
              bottomBar: NookPrimaryButton(
                label: 'Generate Itinerary',
                icon: Icons.auto_awesome_outlined,
                onPressed: usable == 0
                    ? null
                    : () => _generate(trip.name, posts),
              ),
              child: ListView(
                children: [
                  NookAppBar(title: trip.name),
                  const SizedBox(height: NookSpacing.section),
                  ScreenTitle(destination),
                  const SizedBox(height: NookSpacing.tight),
                  Wrap(
                    spacing: NookSpacing.tight,
                    runSpacing: NookSpacing.tight,
                    children: [
                      MetadataChip(
                        '${posts.length} saved '
                        '${posts.length == 1 ? 'post' : 'posts'}',
                        icon: Icons.bookmark_outline_rounded,
                      ),
                      MetadataChip(
                        '$usable with detail',
                        icon: Icons.notes_rounded,
                      ),
                    ],
                  ),
                  if (usable == 0) ...[
                    const SizedBox(height: NookSpacing.section),
                    _NotEnough(tripName: trip.name),
                  ],
                  const SizedBox(height: NookSpacing.block),
                  const RuledLabel('How long is the trip'),
                  const SizedBox(height: NookSpacing.section),
                  Wrap(
                    spacing: NookSpacing.tight,
                    runSpacing: NookSpacing.tight,
                    children: [
                      for (final choice in _choices)
                        SelectableChip(
                          label: '$choice ${choice == 1 ? 'day' : 'days'}',
                          selected: _days == choice,
                          onTap: () => setState(() => _days = choice),
                        ),
                    ],
                  ),
                  const SizedBox(height: NookSpacing.block),
                  RuledLabel('Planning from these $usable'),
                  const SizedBox(height: NookSpacing.section),
                  for (final post in posts) _SourceRow(post: post),
                  const SizedBox(height: NookSpacing.section),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Said plainly rather than left for the generator to refuse.
class _NotEnough extends StatelessWidget {
  const _NotEnough({required this.tripName});

  final String tripName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NookSpacing.section),
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(NookRadius.md),
        border: Border.all(color: NookColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: NookColors.textMuted,
          ),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            child: Text(
              'The posts in $tripName are titles only, so there is nothing to '
              'build days from yet. Open one and add a note, or save a post '
              'that carries more detail.',
              style: NookType.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// One saved post as it will reach the planner: what it is, and what it adds.
class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.post});

  final SavedPost post;

  @override
  Widget build(BuildContext context) {
    final source = ItineraryContext.sourceOf(post);
    final adds = <String>[
      if (source.places.isNotEmpty)
        '${source.places.length} '
            '${source.places.length == 1 ? 'place' : 'places'}',
      if (source.highlights.isNotEmpty) '${source.highlights.length} tips',
      if (source.note != null) 'your note',
      if (source.bestTime != null) 'best time',
      if (source.budgetNote != null) 'budget',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: NookSpacing.tight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostThumbnail(
            url: post.thumbnailUrl,
            width: 44,
            height: 44,
            showGlyph: false,
          ),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: NookType.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  adds.isEmpty
                      ? 'Title only'
                      : adds.join(' · '),
                  style: NookType.caption.copyWith(
                    color: adds.isEmpty
                        ? NookColors.textMuted
                        : NookColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
