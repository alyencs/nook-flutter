import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../ai/platform_from_url.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/metadata_chip.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/thumb_placeholder.dart';
import 'post_draft.dart';

/// A6. Everything the flow gathered, on one screen, before anything is written.
///
/// This is the screen the mockup marks as the best single view of features 1,
/// 2, 3 and 5 together, which is why nothing is saved until the button here.
class ReviewSaveScreen extends StatefulWidget {
  const ReviewSaveScreen({super.key, required this.draft});

  final PostDraft draft;

  @override
  State<ReviewSaveScreen> createState() => _ReviewSaveScreenState();
}

class _ReviewSaveScreenState extends State<ReviewSaveScreen> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final draft = widget.draft;

    await AppScope.of(context).posts.insertPost(
          SavedPostsCompanion.insert(
            title: draft.title,
            creator: Value(draft.creator),
            platform: draft.platform,
            originalUrl: Value(draft.url),
            importMethod: draft.importMethod,
            aiDestination: Value(draft.destination),
            aiCountry: Value(draft.country),
            aiCategory: Value(draft.category),
            aiSummary: Value(draft.summary),
            aiBestTime: Value(draft.bestTime),
            aiBudgetNote: Value(draft.budgetNote),
            tripId: Value(draft.tripId),
            personalNote: Value(draft.note),
            dateSaved: DateTime.now(),
          ),
        );

    if (!mounted) return;
    // Back to whichever tab the flow started from. Home is watching the same
    // stream, so the new post is already there.
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "${draft.title}"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;

    return NookScaffold(
      bottomBar: NookPrimaryButton(
        label: 'Save Post',
        busy: _saving,
        onPressed: _save,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NookAppBar(title: 'Review'),
            const SizedBox(height: NookSpacing.section),
            Text('Review & Save', style: NookType.display),
            const SizedBox(height: NookSpacing.screenEdge),
            Container(
              padding: const EdgeInsets.all(NookSpacing.section),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NookRadius.md),
                border: Border.all(color: NookColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ThumbPlaceholder(
                        width: 72,
                        height: 72,
                        showGlyph: false,
                      ),
                      const SizedBox(width: NookSpacing.section),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Title'),
                            const SizedBox(height: 4),
                            Text(draft.title, style: NookType.title),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NookSpacing.screenEdge),
                  if (!draft.isNote) ...[
                    _Row(
                      label: 'Creator',
                      child: Text(draft.creator ?? '—', style: NookType.bodyStrong),
                    ),
                    _Row(
                      label: 'Platform',
                      child: MetadataChip(NookPlatform.label(draft.platform)),
                    ),
                    _Row(
                      label: 'Destination',
                      child: Text(
                        draft.destination ?? '—',
                        style: NookType.bodyStrong,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                  _Row(
                    label: 'Category',
                    child: MetadataChip(draft.category ?? '—'),
                  ),
                  _Row(
                    label: 'Trip',
                    child: Text(
                      draft.tripName ?? 'No trip',
                      style: NookType.bodyStrong,
                    ),
                  ),
                  if (draft.note != null) ...[
                    const SizedBox(height: NookSpacing.tight),
                    const Divider(),
                    const SizedBox(height: NookSpacing.section),
                    const _FieldLabel('Personal note'),
                    const SizedBox(height: NookSpacing.tight),
                    Text(draft.note!, style: NookType.body),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: NookType.overline);
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NookSpacing.section),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _FieldLabel(label),
          const SizedBox(width: NookSpacing.section),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}
