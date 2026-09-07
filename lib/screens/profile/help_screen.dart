import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/sub_screen_nav.dart';
import 'content_screen.dart';

/// P6.
///
/// The search field filters the topics, and each one opens a real answer.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _query = TextEditingController();
  String _term = '';

  static const _repository = 'https://github.com/alyencs/nook-flutter/issues';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _term.trim().toLowerCase();
    final topics = term.isEmpty
        ? _topics
        : _topics
            .where((t) =>
                t.title.toLowerCase().contains(term) ||
                t.body.toLowerCase().contains(term))
            .toList();

    return NookScaffold(
      bottomNav: const SubScreenNav(),
      child: ListView(
        children: [
          const NookAppBar(title: 'Help & Support'),
          const SizedBox(height: NookSpacing.section),
          _HelpSearchField(
            controller: _query,
            onChanged: (value) => setState(() => _term = value),
          ),
          const SizedBox(height: NookSpacing.block),
          Text('Popular Topics', style: NookType.title),
          const SizedBox(height: NookSpacing.tight),
          if (topics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: NookSpacing.section),
              child: Text(
                'No help articles match "$_term".',
                style: NookType.body.copyWith(color: NookColors.textMuted),
              ),
            )
          else
            for (final topic in topics)
              NookLinkRow(
                label: topic.title,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ContentScreen(
                      title: topic.title,
                      sections: [(null, topic.body)],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: NookSpacing.block),
          Text('Contact', style: NookType.title),
          const SizedBox(height: NookSpacing.section),
          NookSecondaryButton(
            label: 'Send Feedback',
            onPressed: () => _contact(
              context,
              'Send feedback',
              'Feedback goes in the issues tab of the project repository.',
            ),
          ),
          const SizedBox(height: NookSpacing.tight),
          NookSecondaryButton(
            label: 'Report a Bug',
            onPressed: () => _contact(
              context,
              'Report a bug',
              'Bug reports go in the issues tab of the project repository. '
                  'Saying which screen you were on and what you expected helps.',
            ),
          ),
          const SizedBox(height: NookSpacing.section),
        ],
      ),
    );
  }

  /// No mail client and no in-app form, so this hands over the address it can
  /// actually offer and copies it, rather than opening nothing.
  Future<void> _contact(BuildContext context, String title, String body) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: NookColors.surface,
        insetPadding: const EdgeInsets.all(NookSpacing.screenEdge),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(NookSpacing.screenEdge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NookType.title),
              const SizedBox(height: NookSpacing.tight),
              Text(
                body,
                style: NookType.body.copyWith(color: NookColors.textMuted),
              ),
              const SizedBox(height: NookSpacing.section),
              SelectableText(_repository, style: NookType.bodyStrong),
              const SizedBox(height: NookSpacing.block),
              NookPrimaryButton(
                label: 'Copy link',
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: _repository),
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                },
              ),
              const SizedBox(height: NookSpacing.tight),
              NookSecondaryButton(
                label: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _topics = <_Topic>[
    _Topic(
      'How to save a post',
      'Tap Add in the tab bar and choose Paste Link, then paste a URL from '
          'TikTok, Instagram, Facebook or YouTube. Nook reads the link, shows '
          'you what it found, and lets you correct the destination, pick a '
          'trip and add a note before anything is saved. Create Note is the '
          'other way in, for something worth remembering that was never a link.',
    ),
    _Topic(
      'Managing trips',
      'A trip is a group of saved posts. Create one while saving a post, or '
          'from the Trips tab. Moving a post between trips lives behind the "…" '
          'button on the post itself. Deleting a trip keeps its posts — they '
          'simply stop belonging to a trip.',
    ),
    _Topic(
      'AI categories explained',
      'Every saved post gets one category from a fixed list: Food, Travel, '
          'Itinerary, Accommodation, Adventure, Scenery, Nightlife or Other. If '
          'the detected one is wrong, tap a different chip on the Destination & '
          'Category screen — your choice is what gets saved. Turning off '
          '"Auto-categorize saves" in Settings skips detection entirely and '
          'lets you fill the fields in yourself.',
    ),
    _Topic(
      'Supported platforms',
      'TikTok, Instagram, Facebook and YouTube are recognised from the link '
          'and shown with their own mark. Any other link still saves; it is '
          'labelled simply as a link. Preview images are available for YouTube '
          'and usually TikTok — Instagram and Facebook no longer offer a public '
          'way to read one, so those posts show a placeholder.',
    ),
    _Topic(
      'Account issues',
      'There is no account. Nook stores your profile on this device and there '
          'is nothing to sign in to, so there is no password to reset and no '
          'way to be locked out. Account lets you change your name, email and '
          'photo, and "Delete my account" erases everything on this device.',
    ),
  ];
}

class _Topic {
  const _Topic(this.title, this.body);

  final String title;
  final String body;
}

class _HelpSearchField extends StatelessWidget {
  const _HelpSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: NookColors.placeholder,
        borderRadius: BorderRadius.circular(NookRadius.md),
        border: Border.all(color: NookColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: NookSpacing.section),
          const Icon(Icons.search_rounded, size: 20, color: NookColors.textMuted),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: NookType.body,
              cursorColor: NookColors.primary,
              decoration: InputDecoration(
                hintText: 'Search help articles...',
                hintStyle: NookType.body.copyWith(color: NookColors.textMuted),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: NookSpacing.section),
        ],
      ),
    );
  }
}
