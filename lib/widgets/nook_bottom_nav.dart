import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_typography.dart';

/// The tab indices, named so no screen has to remember that Add is 2.
abstract final class NookTabs {
  static const home = 0;
  static const trips = 1;
  static const add = 2;
  static const profile = 3;
}

/// The four tabs, on a Burnt Orange bar.
///
/// The design system describes a white bar with orange active icons; the mockup
/// draws this. Decision 1 in `docs/07-build-plan.md` resolved that in favour of
/// the mockup, and the design system document was updated to match. The bar
/// carries the same left-to-right gradient as a primary button — sampling the
/// mockup across it gives (220,110,13) at the left edge and (195,95,1) at the
/// right, the button's own two stops.
class NookBottomNav extends StatelessWidget {
  const NookBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  /// Index 2 (Add) opens the add flow rather than swapping tabs, so it is never
  /// the current index.
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Trips'),
    (icon: Icons.add_circle_outline, activeIcon: Icons.add_circle, label: 'Add'),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: NookColors.buttonGradient),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    item: _items[i],
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData activeIcon, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? Colors.white : NookColors.onPrimaryMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? item.activeIcon : item.icon, size: 26, color: colour),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: NookType.caption.copyWith(
                color: colour,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
