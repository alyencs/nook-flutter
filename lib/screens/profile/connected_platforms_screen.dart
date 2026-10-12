import 'package:flutter/material.dart';

import '../../ai/platform_from_url.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/sub_screen_nav.dart';
import '../../widgets/platform_badge.dart';

/// Connected Platforms.
///
/// Auto-sync from connected accounts is not built. The screen is drawn as
/// designed with every control disabled and labelled, rather than shipped as
/// buttons that quietly do nothing.
class ConnectedPlatformsScreen extends StatelessWidget {
  const ConnectedPlatformsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomNav: const SubScreenNav(),
      child: ListView(
        children: [
          const NookAppBar(title: 'Connected Platforms'),
          const SizedBox(height: NookSpacing.section),
          Container(
            padding: const EdgeInsets.all(NookSpacing.section),
            decoration: BoxDecoration(
              color: NookColors.secondary,
              borderRadius: BorderRadius.circular(NookRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: NookColors.primary,
                ),
                const SizedBox(width: NookSpacing.tight),
                Expanded(
                  child: Text(
                    'Stretch goal — not in this build. Connecting accounts '
                    'needs each platform\'s API, which is out of scope for the '
                    'MVP. Paste a link instead.',
                    style: NookType.caption.copyWith(
                      color: NookColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NookSpacing.block),
          for (final platform in NookPlatform.supported) ...[
            _PlatformRow(platform: platform),
            const Divider(),
          ],
          const SizedBox(height: NookSpacing.section),
          Text(
            'Connecting accounts would enable automatic saving. Pasting a '
            'link already works for all four — what differs is how much of a '
            'post each platform lets Nook read without an account.',
            style: NookType.body.copyWith(color: NookColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// What Nook can actually read from a pasted link on this platform.
///
/// Stated per platform rather than left implied, because the four are genuinely
/// not equivalent — though less unequal than they were. Nook's service reads
/// each post's public page from a server, which is something the app itself
/// cannot do: a page served from github.io asking instagram.com for a post is
/// a cross-origin request and is refused. That is what used to leave Instagram
/// and Facebook on the link alone, and the reason was never that the posts
/// were unreadable.
///
/// What remains uneven is the creator's profile picture and the richer fields:
/// a public profile page publishes an avatar, and a private one does not.
String _extractionNote(String platform) => switch (platform) {
  NookPlatform.youtube =>
    'Title, description, channel and cover. Add a YouTube API key for the full '
        'description and the channel picture.',
  NookPlatform.tiktok =>
    'Caption, author, cover, and the profile picture when the account is '
        'public.',
  NookPlatform.instagram =>
    'Caption, account and cover from the post\'s public page. Private and '
        'login-only posts cannot be read, and Nook says so rather than '
        'guessing.',
  NookPlatform.facebook =>
    'Post text, page and cover from the post\'s public page. Private posts and '
        'those behind a sign-in cannot be read.',
  _ => 'Read from the link.',
};

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({required this.platform});

  final String platform;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NookSpacing.tight),
      child: Row(
        children: [
          PlatformAvatar(platform: platform, size: 44),
          const SizedBox(width: NookSpacing.section),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(NookPlatform.label(platform), style: NookType.bodyStrong),
                const SizedBox(height: 2),
                Text(_extractionNote(platform), style: NookType.caption),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            child: NookSecondaryButton(label: 'Connect', onPressed: null),
          ),
        ],
      ),
    );
  }
}
