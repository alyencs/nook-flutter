import 'package:flutter/widgets.dart';

import 'nook_colors.dart';

/// The type scale.
///
/// Two faces, with a clear division of labour.
///
/// **Manrope** does the work: body, labels, buttons, navigation, every piece of
/// functional UI. It is the voice of the app.
///
/// **[editorialFamily]** is the accent, and it is deliberately rationed. It is
/// for the two or three words on a screen that should catch the eye first — not
/// for whole headings, and never for anything a person has to read quickly. The
/// pattern is one phrase inside an otherwise Manrope line:
///
/// ```dart
/// NookHeadline('Never lose your *next favourite find*')
/// ```
///
/// A screen with editorial type in more than one place is almost certainly
/// overusing it.
///
/// ---
///
/// **On PP Editorial New.** The design direction calls for it, and it cannot be
/// committed to this repository: it is a licensed face from Pangram Pangram,
/// free for personal use only. What ships here is Instrument Serif (SIL OFL) —
/// a high-contrast editorial serif chosen to sit in the same role. To swap in
/// the real thing once you hold a licence:
///
/// 1. Drop `PPEditorialNew-Regular.otf` and `PPEditorialNew-Italic.otf` into
///    `assets/fonts/`.
/// 2. Point the `EditorialSerif` family in `pubspec.yaml` at them.
///
/// Nothing else changes: every editorial style in the app resolves through
/// [editorialFamily], so the swap is those two edits and nothing more.
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

  /// Section labels above a field: "DETECTED DESTINATION".
  ///
  /// Wider tracking than before, because these now sit on a rule and read as
  /// editorial section marks rather than form labels.
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
  static const displayAccent = TextStyle(
    fontFamily: editorialFamily,
    fontSize: 29,
    height: 1.15,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: NookColors.textPrimary,
    letterSpacing: -0.4,
  );

  /// The emphasised phrase inside a [heading] line.
  static const headingAccent = TextStyle(
    fontFamily: editorialFamily,
    fontSize: 23,
    height: 1.2,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: NookColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// A standalone editorial number or short word — a trip count, a stat.
  static const figure = TextStyle(
    fontFamily: editorialFamily,
    fontSize: 30,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: NookColors.textPrimary,
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
      color: base.color,
      letterSpacing: base.letterSpacing,
    );
  }
}

/// A headline where one phrase is set in the editorial face.
///
/// The emphasis is written inline, wrapped in asterisks, so the call site reads
/// as the sentence it renders:
///
/// ```dart
/// NookHeadline('Never lose your *next favourite find*')
/// ```
///
/// Everything outside the asterisks is [style]; everything inside is its
/// editorial counterpart. This exists so that emphasis is a property of the
/// copy rather than a layout of nested `Text` widgets, which is what makes it
/// survive translation, wrapping and a change of type scale.
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
