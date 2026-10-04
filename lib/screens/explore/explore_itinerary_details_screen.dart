import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../explore/explore_itinerary.dart';
import '../../explore/save_explore_itinerary.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/metadata_chip.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_card.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_rule.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_toast.dart';
import '../../widgets/post_thumbnail.dart';
import '../../widgets/screen_title.dart';

/// One itinerary in full, and the one action it offers.
///
/// Laid out like Travel Details — a cover, the facts as rows, then the detail
/// — because that is the screen in Nook this most resembles. The stops are
/// grouped by day rather than listed flat, which is the only thing an
/// itinerary has that a saved post does not.
class ExploreItineraryDetailsScreen extends StatefulWidget {
  const ExploreItineraryDetailsScreen({super.key, required this.itinerary});

  final ExploreItinerary itinerary;

  @override
  State<ExploreItineraryDetailsScreen> createState() =>
      _ExploreItineraryDetailsScreenState();
}

class _ExploreItineraryDetailsScreenState
    extends State<ExploreItineraryDetailsScreen> {
  /// True from the first tap of Save until the write has finished, so a second
  /// tap cannot create a second trip while the first is still inserting.
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;

    final itinerary = widget.itinerary;
    // Resolved before any await, so nothing reads a BuildContext across one —
    // and so the confirmation still lands after this route has popped.
    final scope = AppScope.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final navigator = Navigator.of(context);

    final already = await exploreItinerarySaved(scope, itinerary);
    if (!mounted) return;

    if (already) {
      final again = await showNookDialog(
        context,
        title: 'Already in your trips',
        message:
            'You saved "${itinerary.title}" before. Add it again as a '
            'separate trip?',
        confirmLabel: 'Add again',
      );
      if (!again || !mounted) return;
    }

    setState(() => _saving = true);

    try {
      final tripId = await saveExploreItinerary(scope, itinerary);
      if (!mounted) return;

      if (tripId == null) {
        setState(() => _saving = false);
        NookToast.show(
          overlay,
          'Set up your profile first, then save an itinerary.',
          isError: true,
        );
        return;
      }

      navigator.pop();
      NookToast.show(
        overlay,
        'Added "${itinerary.title}" to your trips',
        icon: Icons.folder_outlined,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      NookToast.show(
        overlay,
        "That itinerary couldn't be saved. Please try again.",
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final itinerary = widget.itinerary;

    return NookScaffold(
      bottomBar: NookPrimaryButton(
        label: 'Save to My Trips',
        icon: Icons.bookmark_add_outlined,
        busy: _saving,
        onPressed: _save,
      ),
      child: ListView(
        children: [
          NookAppBar(title: itinerary.title),
          const SizedBox(height: NookSpacing.section),
          PostThumbnail(
            url: itinerary.coverImage,
            aspectRatio: 16 / 9,
            radius: NookRadius.md,
            showGlyph: false,
          ),
          const SizedBox(height: NookSpacing.block),
          ScreenTitle(itinerary.title),
          const SizedBox(height: NookSpacing.tight),
          Text(
            itinerary.destination,
            style: NookType.body.copyWith(color: NookColors.textMuted),
          ),
          const SizedBox(height: NookSpacing.section),
          Wrap(
            spacing: NookSpacing.tight,
            runSpacing: NookSpacing.tight,
            children: [
              MetadataChip(
                itinerary.durationLabel,
                icon: Icons.schedule_rounded,
              ),
              MetadataChip(itinerary.stopsLabel, icon: Icons.place_outlined),
              MetadataChip(itinerary.country, icon: Icons.public_rounded),
            ],
          ),
          const SizedBox(height: NookSpacing.block),
          Text(
            itinerary.summary,
            style: NookType.body.copyWith(
              color: NookColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: NookSpacing.block),
          const Divider(),
          _MetaRow(
            icon: Icons.calendar_today_outlined,
            label: 'Best Time to Visit',
            value: itinerary.bestTime,
          ),
          const Divider(),
          _MetaRow(
            icon: Icons.credit_card_rounded,
            label: 'Budget',
            value: itinerary.budgetNote,
          ),
          const Divider(),
          const SizedBox(height: NookSpacing.block),
          for (final day in itinerary.dayNumbers) ...[
            RuledLabel('Day $day'),
            const SizedBox(height: NookSpacing.tight),
            for (final stop in itinerary.stopsOnDay(day)) ...[
              _StopCard(stop: stop),
              const SizedBox(height: NookSpacing.tight),
            ],
            const SizedBox(height: NookSpacing.section),
          ],
          const SizedBox(height: NookSpacing.section),
        ],
      ),
    );
  }
}

/// One stop: its photograph, where it is, and what the itinerary says about it.
class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop});

  final ExploreStop stop;

  @override
  Widget build(BuildContext context) {
    final where = stop.area == null
        ? stop.placeName
        : '${stop.placeName} · ${stop.area}';

    return NookCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PostThumbnail(
                url: stop.image,
                width: 64,
                height: 64,
                showGlyph: false,
              ),
              const SizedBox(width: NookSpacing.tight),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.title,
                      style: NookType.bodyStrong,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      where,
                      style: NookType.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: NookSpacing.tight),
                    MetadataChip(stop.category),
                  ],
                ),
              ),
            ],
          ),
          if (stop.summary.isNotEmpty) ...[
            const SizedBox(height: NookSpacing.tight),
            Text(
              stop.summary,
              style: NookType.body.copyWith(color: NookColors.textMuted),
            ),
          ],
          if (stop.highlights.isNotEmpty) ...[
            const SizedBox(height: NookSpacing.tight),
            for (final line in stop.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7, right: 10),
                      child: SizedBox(width: 14, child: NookRule(opacity: 0.9)),
                    ),
                    Expanded(child: Text(line, style: NookType.body)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A label on the left, its value hard against the right edge.
///
/// Both sides are flex so the two boxes tile the row — a loose label leaves a
/// short value floating in the middle, which is the layout bug Travel Details
/// already had to fix.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

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
