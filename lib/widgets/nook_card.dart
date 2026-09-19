import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';

/// The one card surface in Nook: white, rounded, one soft shadow.
///
/// Material's [Card] brings its own elevation, margin and shape; this keeps all
/// three in the design system instead.
class NookCard extends StatelessWidget {
  const NookCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(10),
    this.radius = NookRadius.md,
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: const [
          BoxShadow(
            color: NookColors.shadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
