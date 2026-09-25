import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'nook_rule.dart';

/// A section title with a rule carrying the eye across to its action.
///
/// The rule is the editorial device: it ties "Recent Saves" on the left to
/// "See All" on the right instead of leaving them as two things that happen to
/// share a row, and it marks where one section ends and the next begins
/// without needing a heavy band of whitespace to do it.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Capped rather than flexed. A `Flexible` title and an `Expanded` rule
        // are both flex children, so they split the free space evenly and a
        // two-word heading wrapped to two lines with a rule beside it. The
        // title takes the width it needs, up to half the row, and the rule
        // takes whatever is left.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.5,
          ),
          child: Text(
            title,
            style: NookType.heading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: NookSpacing.section),
        const Expanded(child: NookRule()),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(NookRadius.sm),
            child: Padding(
              padding: const EdgeInsets.only(
                left: NookSpacing.tight,
                top: NookSpacing.tight,
                bottom: NookSpacing.tight,
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
///
/// Now a [RuledLabel], so every section mark in the app is the same shape.
class OverlineLabel extends StatelessWidget {
  const OverlineLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => RuledLabel(text);
}
