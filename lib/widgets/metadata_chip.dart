import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// Soft Butter pill, Burnt Orange text. Platform, category, or any tag.
class MetadataChip extends StatelessWidget {
  const MetadataChip(this.label, {super.key, this.icon}) : _outlined = false;

  /// Outlined variant: the suggestion chips on the Search screen.
  const MetadataChip.outlined(this.label, {super.key, this.icon})
      : _outlined = true;

  final String label;
  final IconData? icon;
  final bool _outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 12 : 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _outlined ? Colors.transparent : NookColors.secondary,
        borderRadius: BorderRadius.circular(NookRadius.pill),
        border: _outlined ? Border.all(color: NookColors.primary) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: NookColors.primary),
            const SizedBox(width: 6),
          ],
          // Flexible, so a long category can never overflow a narrow card:
          // "Accommodation" is wider than a Recent Saves card allows.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NookType.caption.copyWith(
                color: NookColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable version, used to pick a category on the Add flow.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NookRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? NookColors.primary : NookColors.secondary,
            borderRadius: BorderRadius.circular(NookRadius.pill),
          ),
          child: Text(
            label,
            style: NookType.body.copyWith(
              color: selected ? Colors.white : NookColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
