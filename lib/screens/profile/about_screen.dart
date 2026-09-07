import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/sub_screen_nav.dart';
import '../onboarding/splash_screen.dart';
import 'content_screen.dart';

/// P5.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = 'Version 1.0.0';

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomNav: const SubScreenNav(),
      child: ListView(
        children: [
          const NookAppBar(title: 'About Nook'),
          const SizedBox(height: NookSpacing.block),
          const Center(child: NookMark(size: 88)),
          const SizedBox(height: NookSpacing.section),
          Center(child: Text('Nook', style: NookType.heading)),
          const SizedBox(height: 2),
          Center(
            child: Text(
              _version,
              style: NookType.body.copyWith(color: NookColors.textMuted),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              'Never lose your next favourite idea.',
              style: NookType.body,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          NookLinkRow(
            label: 'Terms of Service',
            onTap: () => _open(context, _terms),
          ),
          NookLinkRow(
            label: 'Privacy Policy',
            onTap: () => _open(context, _privacy),
          ),
          NookLinkRow(
            label: 'Open Source Licenses',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Nook',
              applicationVersion: _version,
            ),
          ),
          NookLinkRow(label: 'Rate Nook', onTap: () => _rate(context)),
          const SizedBox(height: NookSpacing.block),
          Center(
            child: Text(
              'Made with care for content lovers.',
              style: NookType.caption,
            ),
          ),
          const SizedBox(height: NookSpacing.section),
        ],
      ),
    );
  }

  static void _open(BuildContext context, ContentScreen screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// There is no store listing to send anyone to, so this says so rather than
  /// opening nothing.
  static Future<void> _rate(BuildContext context) async {
    await showNookDialog(
      context,
      title: 'Not on a store yet',
      message: 'Nook is a student project and is not published to the App '
          'Store or Google Play, so there is nowhere to leave a rating. The '
          'repository linked from Help & Support is the place for feedback.',
      confirmLabel: 'Got it',
      cancelLabel: 'Close',
    );
  }

  static const _terms = ContentScreen(
    title: 'Terms of Service',
    sections: [
      (
        null,
        'Nook is a student project built for Applications Development and '
            'Emerging Technologies (6ADET) at Holy Angel University. It is '
            'offered as-is, with no warranty and no guarantee of availability.',
      ),
      (
        'What you may do',
        'Use it, read the source, fork it, and build on it. The code is MIT '
            'licensed; the licence text ships with the repository.',
      ),
      (
        'What Nook does not do',
        'It does not host an account, hold your data on a server, or share '
            'anything with anyone. Everything you save stays on your device.',
      ),
      (
        'Content you save',
        'Links you save point at posts owned by their creators and governed by '
            'the terms of the platform they live on. Nook stores your link and '
            'your own notes; it does not copy or redistribute the post.',
      ),
    ],
  );

  static const _privacy = ContentScreen(
    title: 'Privacy Policy',
    sections: [
      (
        null,
        'Short version: everything stays on this device, and there is no '
            'account, no server and no analytics.',
      ),
      (
        'What is stored',
        'Your local profile (name, email and photo if you added one), your '
            'saved posts and their extracted details, your trips, your notes '
            'and your recent searches. All of it lives in a database on this '
            'device.',
      ),
      (
        'What leaves the device',
        'One thing, and only when you save a link: the link itself is sent to '
            'Google Gemini so the destination, category and summary can be '
            'read from it. That happens only in a build configured with an API '
            'key. The published web build has none and uses sample data '
            'instead, which it says on screen. Your notes, your profile and '
            'your trips are never sent anywhere.',
      ),
      (
        'Thumbnails',
        'Preview images are loaded directly from the platform that hosts them '
            '(YouTube, TikTok). Those requests reach that platform the same '
            'way opening any web page would.',
      ),
      (
        'Deleting your data',
        'Settings clears your search history. Account has "Delete my account", '
            'which erases the profile, every saved post and every trip from '
            'this device. Since nothing is stored anywhere else, that is the '
            'whole deletion process — there is no copy to request the removal '
            'of.',
      ),
    ],
  );
}
