import 'package:flutter/material.dart';

import 'app_theme_mode.dart';
import 'palettes/terracotta_palette.dart';
import 'tokens/app_color_scheme.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_typography.dart';
import 'tokens/cuisine_accents.dart';
import 'tokens/palette_tones.dart';

/// Builds the app's `ThemeData` for a light/dark mode.
///
/// This is the single place the app's one `ColorScheme`, the type scale, the
/// cuisine accents and every component style are assembled, so `MaterialApp`
/// just picks between [of]`(AppThemeMode.light)` and [of]`(AppThemeMode.dark)`.
///
/// The warm/humanist direction shows up here at the component level: pill
/// buttons, large rounded cards and sheets, cream-filled inputs with no hard
/// outline, and a flat app bar that sits on the paper rather than floating
/// above it. Platform behaviour (page transitions, scroll physics) is left to
/// the framework's defaults on purpose — only looks are pinned here.
abstract final class AppTheme {
  /// The theme for [mode], built from the app's single palette.
  static ThemeData of({AppThemeMode mode = AppThemeMode.fallback}) =>
      build(terracottaTones, mode.brightness);

  /// Builds a theme straight from tones and a brightness, which is what the
  /// contrast tests and `@Preview`-style galleries want.
  static ThemeData build(PaletteTones tones, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme =
        isDark ? darkColorScheme(tones) : lightColorScheme(tones);
    final CuisineAccents accents =
        isDark ? CuisineAccents.dark(tones) : CuisineAccents.light(tones);
    final TextTheme text = AppTypography.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[accents],
      scaffoldBackgroundColor: scheme.surface,
      // A flat app bar that sits on the page rather than a tinted, elevated
      // one, so the cream surface runs unbroken to the top edge.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      // Paper-like cards: no drop shadow, a soft container tint and the
      // largest rounding the scale offers.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      // Cream-filled fields with no box outline until focused, which is what
      // makes the add/edit form read as one soft column.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: const StadiumBorder(),
        extendedTextStyle: text.labelLarge,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          text.labelMedium?.copyWith(color: scheme.onSurface),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        selectedLabelTextStyle:
            text.labelMedium?.copyWith(color: scheme.onSurface),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle:
            text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.large),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
    );
  }
}
