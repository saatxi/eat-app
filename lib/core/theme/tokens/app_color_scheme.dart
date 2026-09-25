import 'package:flutter/material.dart';

import 'error_tones.dart';
import 'palette_tones.dart';

/// The tone-to-role mapping, written once for every palette.
///
/// This is the piece that used to be duplicated per scheme on Android, and the
/// reason that palette once shipped a contrast bug: `onSecondaryContainer` was
/// hand-wired to tone 40 over a tone 80 container. Here the rule is stated
/// once — an on-container is always the far end of its own ramp — so a new
/// palette cannot reintroduce it. `color_contrast_test.dart` holds the line.
///
/// Flutter's deprecated `background`/`onBackground`/`surfaceVariant` roles are
/// deliberately not set: `surface`/`onSurface` cover the first pair and
/// `surfaceContainerHighest` plus `onSurfaceVariant` cover the third, matching
/// how the current Material 3 widgets read the scheme.
ColorScheme lightColorScheme(PaletteTones tones) {
  final BrandTones primary = tones.primary;
  final BrandTones secondary = tones.secondary;
  final BrandTones tertiary = tones.tertiary;
  final NeutralTones neutral = tones.neutral;
  final NeutralVariantTones variant = tones.neutralVariant;

  return ColorScheme.light(
    primary: primary.t40,
    onPrimary: Colors.white,
    primaryContainer: primary.t90,
    onPrimaryContainer: primary.t10,
    secondary: secondary.t40,
    onSecondary: Colors.white,
    secondaryContainer: secondary.t90,
    onSecondaryContainer: secondary.t10,
    tertiary: tertiary.t40,
    onTertiary: Colors.white,
    tertiaryContainer: tertiary.t90,
    onTertiaryContainer: tertiary.t10,
    error: error40,
    onError: Colors.white,
    errorContainer: error90,
    onErrorContainer: error10,
    surface: neutral.t98,
    onSurface: neutral.t10,
    surfaceDim: neutral.t87,
    surfaceBright: neutral.t98,
    surfaceContainerLowest: neutral.t100,
    surfaceContainerLow: neutral.t96,
    surfaceContainer: neutral.t94,
    surfaceContainerHigh: neutral.t92,
    surfaceContainerHighest: neutral.t90,
    onSurfaceVariant: variant.t30,
    outline: variant.t50,
    outlineVariant: variant.t80,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: neutral.t20,
    onInverseSurface: neutral.t95,
    inversePrimary: primary.t80,
  );
}

ColorScheme darkColorScheme(PaletteTones tones) {
  final BrandTones primary = tones.primary;
  final BrandTones secondary = tones.secondary;
  final BrandTones tertiary = tones.tertiary;
  final NeutralTones neutral = tones.neutral;
  final NeutralVariantTones variant = tones.neutralVariant;

  return ColorScheme.dark(
    primary: primary.t80,
    onPrimary: primary.t20,
    primaryContainer: primary.t30,
    onPrimaryContainer: primary.t90,
    secondary: secondary.t80,
    onSecondary: secondary.t20,
    secondaryContainer: secondary.t30,
    onSecondaryContainer: secondary.t90,
    tertiary: tertiary.t80,
    onTertiary: tertiary.t20,
    tertiaryContainer: tertiary.t30,
    onTertiaryContainer: tertiary.t90,
    error: error80,
    onError: error20,
    errorContainer: error30,
    onErrorContainer: error90,
    surface: neutral.t6,
    onSurface: neutral.t90,
    surfaceDim: neutral.t6,
    surfaceBright: neutral.t24,
    surfaceContainerLowest: neutral.t4,
    surfaceContainerLow: neutral.t10,
    surfaceContainer: neutral.t12,
    surfaceContainerHigh: neutral.t17,
    surfaceContainerHighest: neutral.t22,
    onSurfaceVariant: variant.t80,
    outline: variant.t60,
    outlineVariant: variant.t30,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: neutral.t90,
    onInverseSurface: neutral.t20,
    inversePrimary: primary.t40,
  );
}
