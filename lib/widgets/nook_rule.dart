import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// The line vocabulary.
///
/// Lines separate, label, or carry the eye across a row. A line that is doing
/// none of those three jobs is decoration and does not belong.
///
/// * [NookRule] — a hairline between blocks.
/// * [RuledLabel] — a section mark with the rule running out to the margin.
/// * [RuledRow] — a label and a value with a leader line between them.
class NookRule extends StatelessWidget {
  const NookRule({super.key, this.indent = 0, this.opacity = 1});

  /// Pulls the line in from the left, so a rule under an icon row lines up
  /// with the text rather than the icon.
  final double indent;

  /// For rules that should sit further back than a divider between sections.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: SizedBox(
        height: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NookColors.border.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

/// A section mark: the label, then a rule to the end of the line.
///
/// The rule is what makes a label read as the start of a section rather than a
/// caption on the thing above it. It stretches with an [Expanded], so this
/// needs a bounded width — use [trailing] for an action rather than wrapping
/// the whole thing in a Row.
class RuledLabel extends StatelessWidget {
  const RuledLabel(this.label, {super.key, this.trailing, this.color});

  final String label;

  /// An action at the far right — "See All". The rule stops short of it.
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Capped, not flexed — see the note in SectionHeader: two flex
        // children split the row evenly and the label wraps.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.62,
          ),
          child: Text(
            label.toUpperCase(),
            style: color == null
                ? NookType.overline
                : NookType.overline.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: NookSpacing.tight),
        const Expanded(child: NookRule()),
        if (trailing != null) ...[
          const SizedBox(width: NookSpacing.tight),
          trailing!,
        ],
      ],
    );
  }
}

/// A label and a value, joined by a leader line, the way a contents page does:
/// the line ties the two across a gap that would otherwise read as two
/// unrelated columns.
class RuledRow extends StatelessWidget {
  const RuledRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueStyle,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final TextStyle? valueStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: NookSpacing.row),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: NookColors.textMuted),
            const SizedBox(width: NookSpacing.tight),
          ],
          // Both sides shrink before the row does, and the leader line gives up
          // its width before either piece of text, down to nothing.
          Flexible(
            flex: 6,
            child: Text(
              label,
              style: NookType.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(
                left: NookSpacing.tight,
                right: NookSpacing.tight,
                top: 9,
              ),
              child: const NookRule(opacity: 0.7),
            ),
          ),
          Flexible(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: valueStyle ?? NookType.bodyStrong,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: NookColors.textMuted,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
