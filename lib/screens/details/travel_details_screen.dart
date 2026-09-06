import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/metadata_chip.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/section_header.dart';
import '../../widgets/thumb_placeholder.dart';

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
                  const ThumbPlaceholder(
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
                          style: NookType.bodyStrong.copyWith(fontSize: 18),
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
              const SizedBox(height: NookSpacing.screenEdge),
              const Divider(),
              _MetaRow(
                icon: Icons.place_outlined,
                label: 'Location',
                value: _cityOf(post.aiDestination),
              ),
              const Divider(),
              _MetaRow(
                icon: Icons.public_rounded,
                label: 'Country',
                value: post.aiCountry ?? _countryOf(post.aiDestination),
              ),
              const SizedBox(height: NookSpacing.screenEdge),
              const OverlineLabel('Map location'),
              const SizedBox(height: NookSpacing.tight),
              const _MapPlaceholder(),
              const SizedBox(height: NookSpacing.screenEdge),
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(icon, size: 22, color: NookColors.textPrimary),
          const SizedBox(width: NookSpacing.tight),
          // Flexible so a long label yields to the value rather than pushing
          // it off the edge.
          Flexible(
            child: Text(
              label,
              style: NookType.body.copyWith(fontSize: 17),
            ),
          ),
          const SizedBox(width: NookSpacing.section),
          Expanded(
            child: Text(
              value ?? '—',
              textAlign: TextAlign.right,
              style: NookType.bodyStrong.copyWith(
                fontSize: 17,
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

/// The map is a stretch goal, and this is drawn as a placeholder in the mockup.
///
/// Labelled rather than left blank: an unexplained grey panel reads as broken,
/// and `flutter_map` is deliberately not in this build.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ThumbPlaceholder(aspectRatio: 1.6, showGlyph: false),
        const Positioned(
          top: NookSpacing.tight,
          left: NookSpacing.tight,
          child: MetadataChip('Map View Placeholder'),
        ),
      ],
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
          style: NookType.caption.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}
