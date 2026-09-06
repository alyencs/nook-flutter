import 'package:flutter/material.dart';

import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_text_field.dart';
import 'post_draft.dart';
import 'review_save_screen.dart';

/// A5. Feature #5, at the point it is most useful: while the reason for saving
/// is still in your head.
class PersonalNoteScreen extends StatefulWidget {
  const PersonalNoteScreen({super.key, required this.draft});

  final PostDraft draft;

  @override
  State<PersonalNoteScreen> createState() => _PersonalNoteScreenState();
}

class _PersonalNoteScreenState extends State<PersonalNoteScreen> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _next({required bool keepNote}) {
    final text = _note.text.trim();
    widget.draft.note = keepNote && text.isNotEmpty ? text : null;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReviewSaveScreen(draft: widget.draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NookSecondaryButton(
            label: 'Skip',
            onPressed: () => _next(keepNote: false),
          ),
          const SizedBox(height: NookSpacing.tight),
          NookPrimaryButton(
            label: 'Continue',
            onPressed: () => _next(keepNote: true),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NookAppBar(title: 'Personal Note'),
            const SizedBox(height: NookSpacing.section),
            Text('Add a Note (Optional)', style: NookType.display),
            const SizedBox(height: NookSpacing.screenEdge),
            NookNoteField(
              controller: _note,
              hint: 'Write your thoughts about this post...',
            ),
          ],
        ),
      ),
    );
  }
}
