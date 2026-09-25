import 'package:flutter/material.dart';

import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// The big heading at the top of a screen.
///
/// It exists because the screens had drifted apart: Trips set its heading in
/// `NookType.display` at 25pt, Profile set the same kind of heading in
/// `NookType.title` at 16.5pt, and Add Post had none at all. Three screens, one
/// role, three answers — which is how an app stops looking like one app.
///
/// Deliberately plain Manrope rather than the editorial face. That accent is
/// rationed to four places on purpose, and a serif italic on every screen
/// heading would spend it everywhere and make it mean nothing.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.subtitle});

  final String text;

  /// One line under the title, for a screen that needs to explain itself.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    if (subtitle == null) return Text(text, style: NookType.display);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: NookType.display),
        const SizedBox(height: NookSpacing.tight),
        Text(subtitle!, style: NookType.body),
      ],
    );
  }
}
