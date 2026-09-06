import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_scaffold.dart';

/// P6. Real answers rather than rows that lead nowhere.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int? _open;

  static const _topics = [
    (
      question: 'How to save a post',
      answer: 'Tap Add in the tab bar, choose Paste Link, and paste a URL from '
          'TikTok, Instagram, Facebook or YouTube. Nook reads the link, shows '
          'you what it found, and lets you pick a trip and add a note before '
          'anything is saved.',
    ),
    (
      question: 'Managing trips',
      answer: 'A trip is just a group of saved posts. Create one while saving a '
          'post, or from the Trips tab. Moving a post between trips lives '
          'behind the "…" button on the post itself. Deleting a trip keeps its '
          'posts — they simply stop belonging to a trip.',
    ),
    (
      question: 'AI categories explained',
      answer: 'Every saved post gets one category from a fixed list: Food, '
          'Travel, Itinerary, Accommodation, Adventure, Scenery, Nightlife or '
          'Other. If the detected one is wrong, tap a different chip on the '
          'Destination & Category screen — your choice is what gets saved.',
    ),
    (
      question: 'Supported platforms',
      answer: 'TikTok, Instagram, Facebook and YouTube are recognised by name '
          'and shown with the right label. Any other link still saves; it is '
          'labelled simply as a link.',
    ),
    (
      question: 'Why some details come back empty',
      answer: 'Detection reads the link itself. A URL that names its subject '
          'extracts well; an opaque one may come back without a destination, '
          'and you will see a dash. Every field can be typed in by hand, and '
          'the destination can be edited before saving.',
    ),
    (
      question: 'Your data and this build',
      answer: 'Everything is stored on this device only. The published web '
          'build ships without an AI key, so it uses sample extraction and '
          'says so on screen. Run Nook locally with a Gemini key for real '
          'extraction.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      child: ListView(
        children: [
          const NookAppBar(title: 'Help & Support'),
          const SizedBox(height: NookSpacing.screenEdge),
          Text('Popular Topics', style: NookType.title),
          const SizedBox(height: NookSpacing.tight),
          for (var i = 0; i < _topics.length; i++) ...[
            _TopicRow(
              question: _topics[i].question,
              answer: _topics[i].answer,
              expanded: _open == i,
              onTap: () => setState(() => _open = _open == i ? null : i),
            ),
            const Divider(),
          ],
          const SizedBox(height: NookSpacing.screenEdge),
          Text('Contact', style: NookType.title),
          const SizedBox(height: NookSpacing.tight),
          Text(
            'Nook is a student project for 6ADET at Holy Angel University. '
            'Questions, bugs and suggestions belong in the issues tab of the '
            'repository linked from the README.',
            style: NookType.body.copyWith(color: NookColors.textMuted),
          ),
          const SizedBox(height: NookSpacing.section),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: NookType.body.copyWith(fontSize: 18),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.chevron_right_rounded,
                  color: NookColors.textMuted,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: NookSpacing.tight),
              Text(
                answer,
                style: NookType.body.copyWith(color: NookColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
