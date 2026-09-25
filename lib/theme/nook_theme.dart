import 'package:flutter/material.dart';

import 'nook_colors.dart';
import 'nook_typography.dart';
import 'nook_motion.dart';

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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // One transition on every platform, so the app moves the same way in
          // a browser as it does on a phone. The default on web is no
          // transition at all, which is what makes the flow feel like a slide
          // deck rather than an app.
          TargetPlatform.android: _NookPageTransition(),
          TargetPlatform.iOS: _NookPageTransition(),
          TargetPlatform.macOS: _NookPageTransition(),
          TargetPlatform.windows: _NookPageTransition(),
          TargetPlatform.linux: _NookPageTransition(),
          TargetPlatform.fuchsia: _NookPageTransition(),
        },
      ),      
    );
  }
}

/// A short slide-and-fade from the right.
class _NookPageTransition extends PageTransitionsBuilder {
  const _NookPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: NookMotion.enter,
      reverseCurve: NookMotion.exit,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}