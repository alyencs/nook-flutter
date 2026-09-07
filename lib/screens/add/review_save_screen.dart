import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/daos/settings_dao.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/metadata_chip.dart';
import '../../widgets/platform_badge.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/post_thumbnail.dart';
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
    final draft = widget.draft;
    final scope = AppScope.of(context);

    // Captured before any await and before popping. Reading an inherited
    // widget (ScaffoldMessenger, Navigator, AppScope) through a context whose
    // element is being deactivated registers a dependency that can never be
    // cleaned up, which is what trips
    // "_dependents.isEmpty is not true" in the framework.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // "Save confirmation" in Settings, off by default.
    if (await scope.settings.isEnabled(NookSettings.saveConfirmation)) {
      if (!mounted) return;
      final confirmed = await showNookDialog(
        context,
        title: 'Save this post?',
        message: '"${draft.title}" will be added to '
            '${draft.tripName ?? 'your library'}.',
        confirmLabel: 'Save Post',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _saving = true);

    await scope.posts.insertPost(
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
            aiLatitude: Value(draft.latitude),
            aiLongitude: Value(draft.longitude),
            thumbnailUrl: Value(draft.thumbnailUrl),
            tripId: Value(draft.tripId),
            personalNote: Value(draft.note),
            dateSaved: DateTime.now(),
          ),
        );

    if (!mounted) return;
    // Back to whichever tab the flow started from. Home is watching the same
    // stream, so the new post is already there.
    navigator.popUntil((route) => route.isFirst);
    await showSnackBarAfterPop(messenger, 'Saved "${draft.title}"');
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
            const SizedBox(height: NookSpacing.block),
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
                      PostThumbnail(
                        url: draft.thumbnailUrl,
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
                  const SizedBox(height: NookSpacing.block),
                  if (!draft.isNote) ...[
                    _Row(
                      label: 'Creator',
                      child: Text(draft.creator ?? '—', style: NookType.bodyStrong),
                    ),
                    _Row(
                      label: 'Platform',
                      child: PlatformChip(draft.platform),
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
