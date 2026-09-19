import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// A bold charcoal title with an optional Burnt Orange "See All" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: Text(title, style: NookType.heading)),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(NookRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: NookSpacing.tight,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See All',
                    style: NookType.body.copyWith(
                      color: NookColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: NookColors.primary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The uppercase label above a field: "DETECTED DESTINATION".
class OverlineLabel extends StatelessWidget {
  const OverlineLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: NookType.overline);
}
