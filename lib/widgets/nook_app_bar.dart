import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// The header drawn on every sub-screen: a rounded-square back button, a title,
/// and sometimes one action on the right.
///
/// Not a Material [AppBar] — that brings its own height, elevation and title
/// placement, none of which match what the mockup draws.
class NookAppBar extends StatelessWidget {
  const NookAppBar({super.key, required this.title, this.action, this.onBack});

  final String title;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          _SquareButton(
            icon: Icons.chevron_left_rounded,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            semanticLabel: 'Back',
          ),
          const SizedBox(width: NookSpacing.section),
          Expanded(child: Text(title, style: NookType.title)),
          if (action != null) ...[const SizedBox(width: NookSpacing.tight), action!],
        ],
      ),
    );
  }
}

/// The same square button, exposed for the "…" action on Post Details.
class NookSquareAction extends StatelessWidget {
  const NookSquareAction({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) =>
      _SquareButton(icon: icon, onTap: onTap, semanticLabel: semanticLabel);
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NookRadius.sm),
        child: Container(
          width: NookMetrics.appBarButton,
          height: NookMetrics.appBarButton,
          decoration: BoxDecoration(
            color: NookColors.surface,
            borderRadius: BorderRadius.circular(NookRadius.sm),
            border: Border.all(color: NookColors.textPrimary, width: 1.5),
          ),
          child: Icon(icon, size: 22, color: NookColors.textPrimary),
        ),
      ),
    );
  }
}
