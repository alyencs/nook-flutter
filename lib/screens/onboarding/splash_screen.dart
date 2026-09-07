import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import 'onboarding_screen.dart';

/// LA1. The mark, the name, the line, and one way forward.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomBar: NookPrimaryButton(
        label: 'Continue',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NookMark(size: 96),
            const SizedBox(height: NookSpacing.block),
            Text('Nook', style: NookType.display),
            const SizedBox(height: NookSpacing.tight),
            Text(
              'Never lose your next favourite find.',
              style: NookType.body.copyWith(color: NookColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The app mark: a bookmark in a soft circle. Used on the splash, the About
/// screen and the empty state, so the app has one recognisable glyph.
class NookMark extends StatelessWidget {
  const NookMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: NookColors.placeholder,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.bookmark_outline_rounded,
        size: size * 0.45,
        color: NookColors.primary,
      ),
    );
  }
}
