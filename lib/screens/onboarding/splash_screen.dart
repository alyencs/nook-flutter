import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../theme/nook_motion.dart';
import '../../widgets/logo_assembly.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import 'onboarding_screen.dart';

/// LA1. The mark assembles itself, then the name and the line arrive under it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// True once the four quarters have locked together, which is what brings
  /// the wordmark in underneath.
  bool _assembled = false;

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomBar: AnimatedOpacity(
        // The button waits for the mark. Tapping through a logo animation is
        // allowed — it just is not invited until the mark is whole.
        opacity: _assembled ? 1 : 0.35,
        duration: NookMotion.slow,
        child: NookPrimaryButton(
          label: 'Continue',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen())),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoAssembly(
              size: 116,
              onComplete: () {
                if (mounted) setState(() => _assembled = true);
              },
            ),
            const SizedBox(height: NookSpacing.block),
            // The words follow the mark rather than sharing the screen with
            // it, so the sequence reads as one thing becoming another.
            AnimatedOpacity(
              opacity: _assembled ? 1 : 0,
              duration: NookMotion.slow,
              curve: NookMotion.enter,
              child: AnimatedSlide(
                offset: _assembled ? Offset.zero : const Offset(0, 0.3),
                duration: NookMotion.slow,
                curve: NookMotion.enter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Nook', style: NookType.display),
                    const SizedBox(height: NookSpacing.tight),
                    SizedBox(
                      width: 220,
                      child: NookHeadline(
                        'Never lose your *next favourite find*',
                        style: NookType.body.copyWith(
                          color: NookColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
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
