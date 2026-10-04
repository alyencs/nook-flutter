import 'package:flutter/material.dart';

import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// The big heading at the top of a screen, so one role has one answer rather
/// than a different size per screen.
///
/// Plain Manrope, not the editorial face: that accent is rationed, and a serif
/// italic on every heading would spend it everywhere.
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
