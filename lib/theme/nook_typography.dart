import 'package:flutter/widgets.dart';

import 'nook_colors.dart';

/// The type scale.
///
/// Heading, Body and Caption are the design system's three. Display, Title and
/// Overline are additions: the mockup draws all three (the big "Set Up Profile"
/// heading, app-bar titles, and the uppercase "DETECTED DESTINATION" labels)
/// but the document's 24/16/12 scale has no name for them.
abstract final class NookType {
  static const _family = 'Inter';

  /// Screen-owning headings: "Set Up Profile", "Review & Save".
  static const display = TextStyle(
    fontFamily: _family,
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w700,
    color: NookColors.textPrimary,
    letterSpacing: -0.5,
  );

  /// Screen titles, section headers, trip names.
  static const heading = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: NookColors.textPrimary,
    letterSpacing: -0.3,
  );

  /// App bar titles, card titles.
  static const title = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: NookColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// Saved post titles in lists and cards.
  static const bodyStrong = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: NookColors.textPrimary,
  );

  /// Saved posts, notes, descriptions.
  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: NookColors.textPrimary,
  );

  /// Creator names, platform labels, dates, hints.
  static const caption = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: NookColors.textMuted,
  );

  /// Section labels above a field: "DETECTED DESTINATION".
  static const overline = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: NookColors.textMuted,
    letterSpacing: 0.96, // 0.08em at 12sp
  );

  /// Button labels.
  static const button = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );
}
