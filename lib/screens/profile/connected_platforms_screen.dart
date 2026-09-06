import 'package:flutter/material.dart';

import '../../ai/platform_from_url.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';

/// P4.
///
/// Auto-sync from connected accounts is stretch goal #1, and the mockup itself
/// says to keep it out of the MVP demo path. Drawn as designed, with every
/// control disabled and labelled, rather than shipped as buttons that quietly
/// do nothing.
class ConnectedPlatformsScreen extends StatelessWidget {
  const ConnectedPlatformsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
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
                      fontSize: 13,
                      color: NookColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NookSpacing.screenEdge),
          for (final platform in NookPlatform.supported) ...[
            _PlatformRow(label: NookPlatform.label(platform)),
            const Divider(),
          ],
          const SizedBox(height: NookSpacing.section),
          Text(
            'Connect platforms to enable automatic saving when you share links.',
            style: NookType.body.copyWith(color: NookColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NookSpacing.section),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: NookColors.placeholder,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: NookSpacing.section),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: NookType.bodyStrong.copyWith(fontSize: 18)),
                const SizedBox(height: 2),
                Text(
                  'Not connected',
                  style: NookType.caption.copyWith(fontSize: 14),
                ),
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
