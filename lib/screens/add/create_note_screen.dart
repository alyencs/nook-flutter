import 'package:flutter/material.dart';

import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_text_field.dart';
import 'choose_trip_screen.dart';
import 'post_draft.dart';

/// The second tile on A1: something worth remembering that was never a link.
///
/// It saves a real post with `import_method = 'note'` — no URL, no extraction,
/// no AI call — so it lists, searches and moves between trips like any other.
class CreateNoteScreen extends StatefulWidget {
  const CreateNoteScreen({super.key});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _title = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _continue() {
    final draft = PostDraft.note(
      title: _title.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChooseTripScreen(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomBar: NookPrimaryButton(
        label: 'Continue',
        onPressed: _title.text.trim().isEmpty ? null : _continue,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NookAppBar(title: 'Create Note'),
            const SizedBox(height: NookSpacing.section),
            Text('Write a note', style: NookType.display),
            const SizedBox(height: NookSpacing.screenEdge),
            NookTextField(
              controller: _title,
              hint: 'What is this about?',
              label: 'Title',
              autofocus: true,
            ),
            const SizedBox(height: NookSpacing.section),
            NookNoteField(
              controller: _note,
              hint: 'Write your thoughts...',
              minHeight: 180,
            ),
          ],
        ),
      ),
    );
  }
}
