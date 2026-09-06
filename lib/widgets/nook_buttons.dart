import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// Burnt Orange fill, white label. The one call to action on a screen.
class NookPrimaryButton extends StatelessWidget {
  const NookPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Swaps the label for a spinner. Used while extraction is running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? NookColors.primary : NookColors.border,
        borderRadius: BorderRadius.circular(NookRadius.md),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(NookRadius.md),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: Colors.white),
                          const SizedBox(width: NookSpacing.tight),
                        ],
                        Text(
                          label,
                          style: NookType.button.copyWith(
                            color: enabled
                                ? Colors.white
                                : NookColors.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White fill, grey outline. Sits under a primary button, never beside it.
class NookSecondaryButton extends StatelessWidget {
  const NookSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Soft Red label and border, for Delete Post.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colour = destructive ? NookColors.error : NookColors.textPrimary;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(NookRadius.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(NookRadius.md),
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NookRadius.md),
              border: Border.all(
                color: destructive ? NookColors.error : NookColors.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: colour),
                  const SizedBox(width: NookSpacing.tight),
                ],
                Text(label, style: NookType.button.copyWith(color: colour)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
