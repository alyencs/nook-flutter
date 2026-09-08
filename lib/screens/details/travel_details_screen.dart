import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/section_header.dart';
import '../../widgets/post_map.dart';
import '../../widgets/post_thumbnail.dart';

/// S2. The screen the whole proposal is built around.
///
/// Location, Country, Best Time to Visit and Budget are all extraction results.
/// Any of them can be absent — a link that never named a place cannot produce a
/// budget — and an em dash is the honest answer when that happens.
class TravelDetailsScreen extends StatelessWidget {
  const TravelDetailsScreen({super.key, required this.postId});

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
          bottomBar: const _ExploreItineraryButton(),
          child: ListView(
            children: [
              const NookAppBar(title: 'Travel Details'),
              const SizedBox(height: NookSpacing.section),
              Row(
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
                      children: [
                        Text(
                          post.title,
                          style: NookType.bodyStrong,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.creator ?? '—',
                          style: NookType.body.copyWith(
                            color: NookColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NookSpacing.block),
              const Divider(),
              _MetaRow(
                icon: Icons.place_outlined,
                label: 'Location',
                value: post.aiPlaceName ?? _cityOf(post.aiDestination),
              ),
              const Divider(),
              // The specific parts, each shown only when extraction actually
              // found it. A post that says nothing more than "Japan" still
              // shows Country alone, exactly as before.
              if (post.aiPlaceName != null && post.aiAddress != null)
                _MetaRow(
                  icon: Icons.signpost_outlined,
                  label: 'Address',
                  value: post.aiAddress,
                ),
              if (post.aiNeighbourhood != null)
                _MetaRow(
                  icon: Icons.explore_outlined,
                  label: 'Area',
                  value: post.aiNeighbourhood,
                ),
              if (post.aiCity != null)
                _MetaRow(
                  icon: Icons.location_city_rounded,
                  label: 'City',
                  value: post.aiCity,
                ),
              if (post.aiRegion != null)
                _MetaRow(
                  icon: Icons.map_outlined,
                  label: 'Region',
                  value: post.aiRegion,
                ),
              _MetaRow(
                icon: Icons.public_rounded,
                label: 'Country',
                value: post.aiCountry ?? _countryOf(post.aiDestination),
              ),
              const SizedBox(height: NookSpacing.block),
              const OverlineLabel('Map location'),
              const SizedBox(height: NookSpacing.tight),
              if (post.aiLatitude != null && post.aiLongitude != null)
                PostMap(
                  latitude: post.aiLatitude!,
                  longitude: post.aiLongitude!,
                  label: post.aiPlaceName ??
                      post.aiNeighbourhood ??
                      post.aiCity ??
                      _cityOf(post.aiDestination) ??
                      post.aiDestination ??
                      'Saved location',
                )
              else
                PostMapPlaceholder(
                  reason: post.aiDestination == null
                      ? 'No destination was detected for this post, so there is '
                          'nothing to pin yet. Add one from the post to place it.'
                      : '"${post.aiDestination}" is too broad to place on a map.',
                ),
              const SizedBox(height: NookSpacing.block),
              const Divider(),
              _MetaRow(
                icon: Icons.calendar_today_outlined,
                label: 'Best Time to Visit',
                value: post.aiBestTime,
              ),
              const Divider(),
              _MetaRow(
                icon: Icons.credit_card_rounded,
                label: 'Budget',
                value: post.aiBudgetNote,
              ),
              const Divider(),
              const SizedBox(height: NookSpacing.section),
            ],
          ),
        );
      },
    );
  }

  /// "Kyoto, Japan" splits into a location and a country when the model gave
  /// the pair but not the parts.
  static String? _cityOf(String? destination) {
    if (destination == null) return null;
    final parts = destination.split(',');
    return parts.first.trim().isEmpty ? null : parts.first.trim();
  }

  static String? _countryOf(String? destination) {
    if (destination == null) return null;
    final parts = destination.split(',');
    return parts.length < 2 ? null : parts.last.trim();
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: NookColors.textPrimary),
          const SizedBox(width: NookSpacing.tight),
          // Both sides are flex, so the two boxes tile the whole row and the
          // value box always ends at the right edge.
          //
          // With a loose Flexible label the value box was only half the free
          // space and sat wherever the label happened to end — so short labels
          // like "Location" left their value floating in the middle, while long
          // ones like "Best Time to Visit" looked correctly right-aligned.
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: NookType.body,
            ),
          ),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            flex: 6,
            child: Text(
              value ?? '—',
              textAlign: TextAlign.right,
              style: NookType.bodyStrong.copyWith(
                color: value == null
                    ? NookColors.textMuted
                    : NookColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stretch goal #3, drawn but not built. Disabled and labelled, rather than
/// quietly doing nothing when tapped.
class _ExploreItineraryButton extends StatelessWidget {
  const _ExploreItineraryButton();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NookPrimaryButton(
          label: 'Explore Itinerary',
          icon: Icons.near_me_outlined,
          onPressed: null,
        ),
        const SizedBox(height: NookSpacing.tight),
        Text(
          'Stretch goal — not in this build',
          style: NookType.caption,
        ),
      ],
    );
  }
}
