import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../util/nook_date.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_text_field.dart';
import '../../widgets/post_thumbnail.dart';

/// S3. Feature #5, after the fact.
class PersonalNotesScreen extends StatefulWidget {
  const PersonalNotesScreen({super.key, required this.postId});

  final int postId;

  @override
  State<PersonalNotesScreen> createState() => _PersonalNotesScreenState();
}

class _PersonalNotesScreenState extends State<PersonalNotesScreen> {
  final _note = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    await AppScope.of(context).posts.updateNote(widget.postId, _note.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    navigator.pop();
    await showSnackBarAfterPop(messenger, 'Note saved');
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<SavedPost?>(
      stream: scope.posts.watchPost(widget.postId),
      builder: (context, snapshot) {
        final post = snapshot.data;
        if (post == null) return const NookScaffold(child: SizedBox.shrink());

        // Seed the field once, so a stream rebuild never overwrites typing.
        if (!_loaded) {
          _note.text = post.personalNote ?? '';
          _loaded = true;
        }

        return NookScaffold(
          bottomBar: NookPrimaryButton(
            label: 'Save Changes',
            busy: _saving,
            onPressed: _save,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NookAppBar(title: 'Personal Notes'),
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
                const SizedBox(height: NookSpacing.screenEdge),
                const Divider(),
                const SizedBox(height: NookSpacing.screenEdge),
                Text('Edit notes'.toUpperCase(), style: NookType.overline),
                const SizedBox(height: NookSpacing.tight),
                NookNoteField(
                  controller: _note,
                  hint: 'Write your thoughts about this post...',
                  minLines: 7,
                ),
                if (post.noteEditedAt != null) ...[
                  const SizedBox(height: NookSpacing.section),
                  Text(
                    'Last edited ${formatLongDate(post.noteEditedAt!)}',
                    style: NookType.caption,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
