import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_theme_mode.dart';
import 'tokens/app_color_scheme.dart';
import 'tokens/app_typography.dart';
import 'tokens/cuisine_accents.dart';
import 'tokens/palette_tones.dart';

/// Builds the app's `ThemeData` from a palette and a light/dark mode.
///
/// This is the single place a `ColorScheme`, the type scale and the cuisine
/// accents are assembled, so `MaterialApp` just picks between
/// [of]`(..., AppThemeMode.light)` and [of]`(..., AppThemeMode.dark)`.
abstract final class AppTheme {
  /// The theme for [palette] in [mode].
  static ThemeData of({
    AppPalette palette = AppPalette.fallback,
    AppThemeMode mode = AppThemeMode.fallback,
  }) =>
      build(palette.tones, mode.brightness);

  /// Builds a theme straight from tones and a brightness, which is what the
  /// contrast tests and `@Preview`-style galleries want.
  static ThemeData build(PaletteTones tones, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme =
        isDark ? darkColorScheme(tones) : lightColorScheme(tones);
    final CuisineAccents accents =
        isDark ? CuisineAccents.dark(tones) : CuisineAccents.light(tones);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: AppTypography.textTheme,
      extensions: <ThemeExtension<dynamic>>[accents],
      // The editorial treatment wants a flat app bar that sits on the page
      // rather than a tinted, elevated one, so the M3 surface tint is dropped.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
