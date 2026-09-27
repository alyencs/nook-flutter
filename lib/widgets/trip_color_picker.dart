import 'package:flutter/material.dart';

import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import '../theme/trip_colors.dart';

/// Five swatches, one chosen.
///
/// Five rather than a colour wheel: the job is telling four trips apart at a
/// glance, and a wheel would mostly produce colours that fight the app. Each
/// swatch is the folder it will become, not an abstract dot, so the choice is
/// made against the thing itself.
class TripColorPicker extends StatelessWidget {
  const TripColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final TripColor selected;
  final ValueChanged<TripColor> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final colour in TripColor.values) ...[
          Expanded(
            child: _Swatch(
              colour: colour,
              selected: colour == selected,
              onTap: () => onSelected(colour),
            ),
          ),
          if (colour != TripColor.values.last)
            const SizedBox(width: NookSpacing.tight),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final TripColor colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: colour.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NookRadius.sm),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: colour.fill,
                  borderRadius: BorderRadius.circular(NookRadius.sm),
                  // The ring, not a tick inside the swatch: a mark on top of
                  // the colour changes the colour you are judging.
                  border: Border.all(
                    color: selected ? TripColor.selectedRing : colour.edge,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  size: 20,
                  color: colour.ink,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              colour.label,
              style: NookType.caption.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
