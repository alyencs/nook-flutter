import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';

/// Every screen in Nook sits on this.
///
/// It owns the warm gradient the mockup draws behind all content — off-white at
/// the top, Soft Butter at the foot — so no screen repeats it and none of them
/// can drift apart.
class NookScaffold extends StatelessWidget {
  const NookScaffold({
    super.key,
    required this.child,
    this.bottomNav,
    this.bottomBar,
    this.padHorizontal = true,
  });

  final Widget child;

  /// The orange tab bar, on the four root screens only.
  final Widget? bottomNav;

  /// A pinned action area above the home indicator: "Continue", "Save Post".
  final Widget? bottomBar;

  /// Screens with edge-to-edge scrolling content manage their own padding.
  final bool padHorizontal;

  @override
  Widget build(BuildContext context) {
    final content = padHorizontal
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NookSpacing.screenEdge,
            ),
            child: child,
          )
        : child;

    return Scaffold(
      backgroundColor: NookColors.background,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: NookColors.screenGradient),
        child: SafeArea(
          bottom: bottomNav == null,
          child: Column(
            children: [
              Expanded(child: content),
              if (bottomBar != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    NookSpacing.screenEdge,
                    NookSpacing.section,
                    NookSpacing.screenEdge,
                    bottomNav == null ? NookSpacing.tight : NookSpacing.section,
                  ),
                  child: bottomBar,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottomNav,
    );
  }
}
