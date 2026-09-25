import 'package:flutter/material.dart';

/// The editorial type scale.
///
/// [displayFamily] (Fraunces, a contemporary "wonky" serif) carries
/// display/headline/title; [bodyFamily] (Manrope, a geometric sans) carries
/// body/label. That split is the same one the Android app's `Type.kt` uses, so
/// the Flutter rewrite keeps the app's voice rather than re-opening the type
/// question.
///
/// Fraunces is bundled as a single **variable** font, so weights and the
/// optical-size axis are selected per style through `fontVariations` instead
/// of by shipping a file per weight. Manrope is not variable, so its static
/// instances are selected by `fontWeight` alone.
abstract final class AppTypography {
  /// Display/headline/title family — bundled at
  /// `assets/fonts/fraunces_variable.ttf`.
  static const String displayFamily = 'Fraunces';

  /// Body/label family — bundled at `assets/fonts/manrope_*.ttf`.
  static const String bodyFamily = 'Manrope';

  /// Tabular numerals, so digits keep a constant width as counts change.
  ///
  /// Applied selectively (ratings, statistics) rather than to the whole scale,
  /// the way the Android app's stat tiles set `fontFeatureSettings = "tnum"`.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// The M3 type scale, spelled out in full.
  static final TextTheme textTheme = TextTheme(
    displayLarge: _display(size: 57, lineHeight: 64, weight: 400, letterSpacing: -0.25),
    displayMedium: _display(size: 45, lineHeight: 52, weight: 400),
    displaySmall: _display(size: 36, lineHeight: 44, weight: 400),
    headlineLarge: _display(size: 32, lineHeight: 40, weight: 600),
    headlineMedium: _display(size: 28, lineHeight: 36, weight: 600),
    headlineSmall: _display(size: 24, lineHeight: 32, weight: 600),
    titleLarge: _display(size: 22, lineHeight: 28, weight: 600),
    titleMedium: _body(size: 18, lineHeight: 24, weight: 600, letterSpacing: 0.15),
    titleSmall: _body(size: 14, lineHeight: 20, weight: 500, letterSpacing: 0.1),
    bodyLarge: _body(size: 16, lineHeight: 24, weight: 400, letterSpacing: 0.5),
    bodyMedium: _body(size: 14, lineHeight: 20, weight: 400, letterSpacing: 0.25),
    bodySmall: _body(size: 12, lineHeight: 16, weight: 400, letterSpacing: 0.4),
    labelLarge: _body(size: 14, lineHeight: 20, weight: 600, letterSpacing: 0.1),
    labelMedium: _body(size: 12, lineHeight: 16, weight: 600, letterSpacing: 0.5),
    labelSmall: _body(size: 11, lineHeight: 16, weight: 500, letterSpacing: 0.5),
  );

  static TextStyle _display({
    required double size,
    required double lineHeight,
    required double weight,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontWeight: _weight(weight),
      fontSize: size,
      height: lineHeight / size,
      letterSpacing: letterSpacing,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight),
        // Keep the optical-size axis in step with the rendered size, which is
        // what lets the serif hold up at 57px and stay legible at 22px.
        FontVariation('opsz', size),
      ],
    );
  }

  static TextStyle _body({
    required double size,
    required double lineHeight,
    required double weight,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: bodyFamily,
      fontWeight: _weight(weight),
      fontSize: size,
      height: lineHeight / size,
      letterSpacing: letterSpacing,
    );
  }

  static FontWeight _weight(double value) {
    return switch (value) {
      400 => FontWeight.w400,
      500 => FontWeight.w500,
      600 => FontWeight.w600,
      700 => FontWeight.w700,
      800 => FontWeight.w800,
      _ => FontWeight.w400,
    };
  }
}
