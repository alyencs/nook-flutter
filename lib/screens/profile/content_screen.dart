import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/sub_screen_nav.dart';

/// A heading and some prose. Behind the rows on About Nook and Help & Support,
/// so every chevron leads somewhere real instead of doing nothing.
class ContentScreen extends StatelessWidget {
  const ContentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;

  /// Heading to body. A null heading renders as a lead paragraph.
  final List<(String?, String)> sections;

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomNav: const SubScreenNav(),
      child: ListView(
        children: [
          NookAppBar(title: title),
          const SizedBox(height: NookSpacing.section),
          for (final (heading, body) in sections) ...[
            if (heading != null) ...[
              Text(heading, style: NookType.title),
              const SizedBox(height: NookSpacing.tight),
            ],
            Text(
              body,
              style: NookType.body.copyWith(color: NookColors.textMuted),
            ),
            const SizedBox(height: NookSpacing.screenEdge),
          ],
        ],
      ),
    );
  }
}

/// A label with a chevron. The row shape used by both About and Help.
class NookLinkRow extends StatelessWidget {
  const NookLinkRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(child: Text(label, style: NookType.body)),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: NookColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
