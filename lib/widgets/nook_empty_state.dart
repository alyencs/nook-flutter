import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'nook_buttons.dart';

/// Centred outlined glyph, a heading, a line of explanation, and one way out.
class NookEmptyState extends StatelessWidget {
  const NookEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: NookColors.placeholder,
              shape: BoxShape.circle,
              border: Border.all(color: NookColors.primary, width: 2),
            ),
            child: Icon(icon, size: 40, color: NookColors.primary),
          ),
          const SizedBox(height: NookSpacing.screenEdge),
          Text(title, style: NookType.heading, textAlign: TextAlign.center),
          const SizedBox(height: NookSpacing.tight),
          Text(
            message,
            style: NookType.body.copyWith(color: NookColors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: NookSpacing.screenEdge),
            NookPrimaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
