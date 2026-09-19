import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import 'profile_setup_screen.dart';

/// LA6, formerly "Sign In Method".
///
/// There is no "Continue with Google" and no "Continue with Email" here, and
/// that absence is the point: with Drift on the device and no server, there is
/// nothing to sign in to. One button, straight to a local profile.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomBar: NookPrimaryButton(
        label: 'Get Started',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          Text(
            'Welcome to Nook',
            style: NookType.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NookSpacing.tight),
          Text(
            'Your travel content, saved in one place',
            style: NookType.body.copyWith(
              color: NookColors.textMuted,
              ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
