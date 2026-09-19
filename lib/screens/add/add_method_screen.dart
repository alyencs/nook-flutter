import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_scaffold.dart';
import 'create_note_screen.dart';
import 'paste_link_screen.dart';

/// A1. Two ways in.
class AddMethodScreen extends StatelessWidget {
  const AddMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NookAppBar(title: 'Add Post'),
          const SizedBox(height: NookSpacing.section),
          _MethodTile(
            icon: Icons.link_rounded,
            title: 'Paste Link',
            subtitle: 'Save a post from social media',
            emphasised: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PasteLinkScreen()),
            ),
          ),
          const SizedBox(height: NookSpacing.section),
          _MethodTile(
            icon: Icons.edit_outlined,
            title: 'Create Note',
            subtitle: 'Write a personal note',
            emphasised: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateNoteScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emphasised,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Paste Link is drawn with a heavier border: it is the main path.
  final bool emphasised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NookRadius.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(NookSpacing.screenEdge),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NookRadius.md),
          border: Border.all(
            color: emphasised ? NookColors.textPrimary : NookColors.border,
            width: emphasised ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: NookColors.placeholder,
                borderRadius: BorderRadius.circular(NookRadius.sm),
              ),
              child: Icon(icon, size: 26, color: NookColors.textPrimary),
            ),
            const SizedBox(height: NookSpacing.section),
            Text(title, style: NookType.title),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: NookType.body.copyWith(color: NookColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
