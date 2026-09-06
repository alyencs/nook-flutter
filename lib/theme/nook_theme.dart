import 'package:flutter/material.dart';

import 'nook_colors.dart';
import 'nook_typography.dart';

/// Nook's Material theme.
///
/// Deliberately thin: the app draws its own buttons, cards, chips and app bars
/// from the design system, so this exists mostly to stop Material's defaults
/// leaking in — the purple seed palette, Roboto, and the elevation shadows
/// under everything.
abstract final class NookTheme {
  static ThemeData get theme {
    const scheme = ColorScheme.light(
      primary: NookColors.primary,
      onPrimary: Colors.white,
      secondary: NookColors.secondary,
      onSecondary: NookColors.primary,
      surface: NookColors.surface,
      onSurface: NookColors.textPrimary,
      error: NookColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      // Screens paint the warm gradient themselves; a solid colour behind it
      // would show through on over-scroll.
      scaffoldBackgroundColor: NookColors.background,
      splashFactory: InkRipple.splashFactory,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: NookColors.primary,
        selectionColor: NookColors.secondary,
        selectionHandleColor: NookColors.primary,
      ),
      textTheme: const TextTheme(
        displayMedium: NookType.display,
        headlineMedium: NookType.heading,
        titleLarge: NookType.title,
        bodyLarge: NookType.body,
        bodyMedium: NookType.body,
        labelSmall: NookType.caption,
      ),
      dividerTheme: const DividerThemeData(
        color: NookColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NookColors.textPrimary,
        contentTextStyle: NookType.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
