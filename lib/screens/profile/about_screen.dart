import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_scaffold.dart';
import '../onboarding/splash_screen.dart';

/// P5.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      child: ListView(
        children: [
          const NookAppBar(title: 'About Nook'),
          const SizedBox(height: NookSpacing.screenEdge),
          const Center(child: NookMark(size: 96)),
          const SizedBox(height: NookSpacing.section),
          Center(child: Text('Nook', style: NookType.display.copyWith(fontSize: 30))),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Version 1.0.0',
              style: NookType.body.copyWith(color: NookColors.textMuted),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Never lose your next favourite find.',
              style: NookType.body.copyWith(fontSize: 17),
            ),
          ),
          const SizedBox(height: 40),
          const _AboutSection(
            title: 'What Nook does',
            body: 'Travellers find destinations, itineraries and tips scattered '
                'across TikTok, Instagram, Facebook and YouTube. Saving them '
                'inside each app scatters trip research across four places. '
                'Nook keeps them in one, grouped by trip and searchable across '
                'every platform.',
          ),
          const _AboutSection(
            title: 'Where your data lives',
            body: 'On this device, in a local database, and nowhere else. There '
                'is no account and no server: nothing you save is uploaded, '
                'shared or synced. Clearing your data in Settings is the whole '
                'deletion process.',
          ),
          const _AboutSection(
            title: 'About the AI',
            body: 'Destination and category detection runs on Google Gemini '
                'when Nook is run locally with an API key. The published web '
                'build ships without one — a billable key must never be '
                'compiled into a public site — so it uses sample extraction '
                'instead, and says so on screen when it does.',
          ),
          const _AboutSection(
            title: 'Credits',
            body: 'Built with Flutter. Local storage by Drift. Typeface: Inter '
                'by Rasmus Andersson, under the SIL Open Font License. Every '
                'trip, post, handle and link in the demo library is fictional.',
          ),
          const SizedBox(height: NookSpacing.screenEdge),
          Center(
            child: Text(
              'Made with care for people who keep losing links.',
              style: NookType.caption.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: NookSpacing.section),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NookSpacing.screenEdge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: NookType.title),
          const SizedBox(height: NookSpacing.tight),
          Text(
            body,
            style: NookType.body.copyWith(color: NookColors.textMuted),
          ),
        ],
      ),
    );
  }
}
