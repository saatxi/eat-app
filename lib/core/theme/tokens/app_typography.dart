import 'package:flutter/material.dart';

/// The humanist type scale.
///
/// [displayFamily] (Lora, a warm contemporary serif) carries
/// display/headline/title; [bodyFamily] (Nunito, a rounded humanist sans)
/// carries body/label. A friendly serif over a soft sans is what gives the app
/// its notebook feel — warmer than a geometric sans alone, and easier to read
/// at length than a wonky display serif.
///
/// Both families ship as single **variable** fonts (one `wght` axis each), so
/// the weight is selected per style through `fontVariations` — and mirrored on
/// `fontWeight` for the platforms that read that first — rather than by
/// bundling a static file per weight.
abstract final class AppTypography {
  /// Display/headline/title family — bundled at
  /// `assets/fonts/lora_variable.ttf`.
  static const String displayFamily = 'Lora';

  /// Body/label family — bundled at `assets/fonts/nunito_variable.ttf`.
  static const String bodyFamily = 'Nunito';

  /// Tabular numerals, so digits keep a constant width as counts change.
  ///
  /// Applied selectively (ratings, statistics) rather than to the whole scale,
  /// the way the Android app's stat tiles set `fontFeatureSettings = "tnum"`.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// The M3 type scale, spelled out in full, tuned a touch larger and looser
  /// than the stock scale for the humanist read.
  static final TextTheme textTheme = TextTheme(
    displayLarge: _display(size: 56, lineHeight: 64, weight: 400, letterSpacing: -0.5),
    displayMedium: _display(size: 44, lineHeight: 52, weight: 400),
    displaySmall: _display(size: 36, lineHeight: 44, weight: 400),
    headlineLarge: _display(size: 32, lineHeight: 40, weight: 500),
    headlineMedium: _display(size: 28, lineHeight: 36, weight: 500),
    headlineSmall: _display(size: 24, lineHeight: 32, weight: 600),
    titleLarge: _display(size: 22, lineHeight: 28, weight: 600),
    titleMedium: _body(size: 17, lineHeight: 24, weight: 600, letterSpacing: 0.1),
    titleSmall: _body(size: 15, lineHeight: 20, weight: 600, letterSpacing: 0.1),
    bodyLarge: _body(size: 16, lineHeight: 26, weight: 400, letterSpacing: 0.15),
    bodyMedium: _body(size: 14, lineHeight: 22, weight: 400, letterSpacing: 0.2),
    bodySmall: _body(size: 12, lineHeight: 18, weight: 400, letterSpacing: 0.3),
    labelLarge: _body(size: 15, lineHeight: 20, weight: 700, letterSpacing: 0.1),
    labelMedium: _body(size: 12, lineHeight: 16, weight: 700, letterSpacing: 0.4),
    labelSmall: _body(size: 11, lineHeight: 16, weight: 600, letterSpacing: 0.5),
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
      fontVariations: <FontVariation>[FontVariation('wght', weight)],
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
      fontVariations: <FontVariation>[FontVariation('wght', weight)],
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
