import 'package:flutter/widgets.dart';

import 'nook_colors.dart';

/// The type scale.
///
/// Manrope does the functional work — body, labels, buttons, navigation.
/// [editorialFamily] is the accent and is rationed to the two or three words on
/// a screen that should catch the eye first:
///
/// ```dart
/// NookHeadline('Never lose your *next favourite find*')
/// ```
///
/// Editorial type in more than one place on a screen is almost certainly
/// overuse.
///
/// The design calls for PP Editorial New, which is licensed and cannot be
/// committed; Instrument Serif (SIL OFL) stands in. Swapping it is two edits —
/// the font files into `assets/fonts/`, and the `EditorialSerif` family in
/// `pubspec.yaml` — because every editorial style resolves through
/// [editorialFamily].
abstract final class NookType {
  /// The UI face. Everything functional.
  static const family = 'Manrope';

  /// The accent face. One phrase at a time.
  static const editorialFamily = 'EditorialSerif';

  /// Screen-owning headings: "Set Up Profile", "Review & Save".
  static const display = TextStyle(
    fontFamily: family,
    fontSize: 25,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: NookColors.textPrimary,
    letterSpacing: -0.6,
  );

  /// Screen titles, section headers, trip names.
  static const heading = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: NookColors.textPrimary,
    letterSpacing: -0.4,
  );

  /// App bar titles, card titles.
  static const title = TextStyle(
    fontFamily: family,
    fontSize: 16.5,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: NookColors.textPrimary,
    letterSpacing: -0.25,
  );

  /// Saved post titles in lists and cards.
  static const bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: NookColors.textPrimary,
  );

  /// Saved posts, notes, descriptions.
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: NookColors.textPrimary,
  );

  /// Creator names, platform labels, dates, hints.
  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: NookColors.textMuted,
  );

  /// Section labels above a field: "DETECTED DESTINATION". Tracked wide,
  /// because these sit on a rule and read as section marks, not form labels.
  static const overline = TextStyle(
    fontFamily: family,
    fontSize: 10,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: NookColors.textMuted,
    letterSpacing: 1.4,
  );

  /// Button labels.
  static const button = TextStyle(
    fontFamily: family,
    fontSize: 14.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );

  // --- The accent face. Sizes match their Manrope counterparts, because an
  // emphasised phrase sits on the same line as the words around it.

  /// The emphasised phrase inside a [display] line.
  /// The editorial face is always Nook's orange: a serif italic in charcoal
  /// reads as a different font rather than as the same voice raised.
  static const accentColor = NookColors.primary;

  static const displayAccent = TextStyle(
    fontFamily: editorialFamily,
    fontSize: 29,
    height: 1.15,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: accentColor,
    letterSpacing: -0.4,
  );

  /// The emphasised phrase inside a [heading] line.
  static const headingAccent = TextStyle(
    fontFamily: editorialFamily,
    fontSize: 23,
    height: 1.2,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: accentColor,
    letterSpacing: -0.2,
  );

  /// A standalone editorial number or short word — a trip count, a stat.
  static const figure = TextStyle(
    fontFamily: editorialFamily,
    fontSize: 30,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: accentColor,
  );

  /// The accent style that pairs with [base].
  static TextStyle accentFor(TextStyle base) {
    if (base.fontSize == null) return displayAccent;
    if (base.fontSize! >= 24) return displayAccent;
    if (base.fontSize! >= 18) return headingAccent;
    return TextStyle(
      fontFamily: editorialFamily,
      fontSize: base.fontSize! * 1.16,
      height: base.height,
      fontStyle: FontStyle.italic,
      // The accent is the orange, whatever colour the plain run is.
      color: accentColor,
      letterSpacing: base.letterSpacing,
    );
  }
}

/// A headline where one phrase is set in the editorial face.
///
/// ```dart
/// NookHeadline('Never lose your *next favourite find*')
/// ```
///
/// Outside the asterisks is [style], inside is its editorial counterpart.
/// Emphasis as a property of the copy rather than nested `Text` widgets, so it
/// survives wrapping and a change of type scale.
class NookHeadline extends StatelessWidget {
  const NookHeadline(
    this.template, {
    super.key,
    this.style,
    this.accentStyle,
    this.textAlign,
    this.maxLines,
  });

  final String template;
  final TextStyle? style;
  final TextStyle? accentStyle;
  final TextAlign? textAlign;
  final int? maxLines;

  /// Splits on `*…*`, alternating plain and emphasised runs.
  static List<TextSpan> spansFor(
    String template,
    TextStyle base,
    TextStyle accent,
  ) {
    final spans = <TextSpan>[];
    var plain = true;
    for (final part in template.split('*')) {
      if (part.isNotEmpty) {
        spans.add(TextSpan(text: part, style: plain ? base : accent));
      }
      plain = !plain;
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? NookType.display;
    final accent = accentStyle ?? NookType.accentFor(base);

    return Text.rich(
      TextSpan(children: spansFor(template, base, accent)),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
