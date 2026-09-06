import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/daos/trips_dao.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/trip_card.dart';
import 'personal_note_screen.dart';
import 'post_draft.dart';
import 'review_save_screen.dart';

/// A4. Feature #3: which trip this belongs to.
class ChooseTripScreen extends StatefulWidget {
  const ChooseTripScreen({super.key, required this.draft});

  final PostDraft draft;

  @override
  State<ChooseTripScreen> createState() => _ChooseTripScreenState();
}

class _ChooseTripScreenState extends State<ChooseTripScreen> {
  int? _selected;

  Future<void> _createTrip() async {
    final name = await showCreateTripDialog(context);
    if (name == null || !mounted) return;

    final scope = AppScope.of(context);
    final user = await scope.users.currentUser();
    if (user == null) return;

    final id = await scope.trips.createTrip(name, user.id);
    if (!mounted) return;
    setState(() => _selected = id);
  }

  void _continue(List<TripSummary> trips) {
    widget.draft
      ..tripId = _selected
      ..tripName = _selected == null
          ? null
          : trips.firstWhere((t) => t.trip.id == _selected).trip.name;

    // A note already carries its text, so it skips the note step.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.draft.isNote
            ? ReviewSaveScreen(draft: widget.draft)
            : PersonalNoteScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<List<TripSummary>>(
      stream: scope.trips.watchTripSummaries(),
      builder: (context, snapshot) {
        final trips = snapshot.data ?? const <TripSummary>[];

        return NookScaffold(
          bottomBar: NookPrimaryButton(
            label: 'Continue',
            onPressed: () => _continue(trips),
          ),
          child: ListView(
            children: [
              const NookAppBar(title: 'Trip'),
              const SizedBox(height: NookSpacing.section),
              Text('Add to trip'.toUpperCase(), style: NookType.overline),
              const SizedBox(height: NookSpacing.section),
              for (final summary in trips)
                _TripRow(
                  summary: summary,
                  selected: _selected == summary.trip.id,
                  onTap: () => setState(() => _selected = summary.trip.id),
                ),
              const SizedBox(height: NookSpacing.tight),
              InkWell(
                onTap: _createTrip,
                borderRadius: BorderRadius.circular(NookRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: NookSpacing.section,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 26),
                      const SizedBox(width: NookSpacing.tight),
                      Text('Create New Trip', style: NookType.title),
                      const SizedBox(width: NookSpacing.tight),
                      Flexible(
                        child: Text(
                          'e.g. Japan 2027',
                          style: NookType.body.copyWith(
                            color: NookColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final TripSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NookRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: NookSpacing.tight),
          child: Row(
            children: [
              const TripFolderTile(),
              const SizedBox(width: NookSpacing.section),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.trip.name,
                      style: NookType.bodyStrong.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.itemCount} '
                      '${summary.itemCount == 1 ? 'item' : 'items'}',
                      style: NookType.caption.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? NookColors.textPrimary : Colors.transparent,
                  border: Border.all(color: NookColors.textPrimary, width: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
