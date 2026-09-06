import 'package:flutter/widgets.dart';

/// Every colour in Nook, and nothing else.
///
/// The first six come straight from the design system document. The last three
/// are additions recorded in `docs/07-build-plan.md`: the mockup clearly draws
/// captions and inactive navigation in a lighter grey than the one body colour
/// the document names, and draws a warm gradient behind every screen.
abstract final class NookColors {
  /// Primary buttons, active navigation, links, accents.
  static const primary = Color(0xFFDD700B);

  /// Chip fills, selected states, the foot of the screen gradient.
  static const secondary = Color(0xFFFCF8D8);

  /// The head of the screen gradient.
  static const background = Color(0xFFFAFAF8);

  /// Cards, search bar, dialogs.
  static const surface = Color(0xFFFFFFFF);

  /// Validation errors, delete actions.
  static const error = Color(0xFFD9534F);

  /// Body copy and headings.
  static const textPrimary = Color(0xFF2E2E2E);

  /// Field and card outlines.
  static const border = Color(0xFFD9DADF);

  /// Creator names, captions, section labels, inactive navigation.
  static const textMuted = Color(0xFF8A8F98);

  /// Thumbnail and avatar placeholder fills.
  static const placeholder = Color(0xFFF0F1F4);

  /// Inactive navigation items, sitting on [primary].
  static const onPrimaryMuted = Color(0x99FFFFFF);

  /// The single shadow in the app: 6% charcoal.
  static const shadowColor = Color(0x0F2E2E2E);

  /// Behind every screen, top to bottom.
  static const screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, secondary],
  );
}
