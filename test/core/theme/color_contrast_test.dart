import 'dart:math' as math;

import 'package:eatapp/core/theme/app_palette.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/core/theme/tokens/cuisine_accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tone-to-role mapping states the rule "an on-colour is always the far end
/// of its own ramp" once, for every palette. This holds the line: it walks all
/// three palettes in both brightnesses and asserts the WCAG AA normal-text
/// threshold (4.5:1) on every foreground/background pair the scheme exposes,
/// including the cuisine accents.
///
/// Port of the Android app's `ColorSchemeContrastTest`, so the rewrite cannot
/// quietly reintroduce the hand-wired `onSecondaryContainer` bug that test was
/// written to catch.
const double _aaNormalText = 4.5;

/// Small slack for floating-point rounding; the palettes are tuned to clear the
/// threshold, not to sit exactly on it.
const double _epsilon = 0.01;

void main() {
  const List<AppPalette> palettes = AppPalette.values;
  const List<Brightness> brightnesses = <Brightness>[
    Brightness.light,
    Brightness.dark,
  ];

  for (final AppPalette palette in palettes) {
    for (final Brightness brightness in brightnesses) {
      final String label = '${palette.id} / ${brightness.name}';
      final ThemeData theme = AppTheme.build(palette.tones, brightness);
      final ColorScheme scheme = theme.colorScheme;

      test('$label — brand on-colours clear AA', () {
        _expectAa(scheme.primary, scheme.onPrimary, 'onPrimary');
        _expectAa(scheme.primaryContainer, scheme.onPrimaryContainer, 'onPrimaryContainer');
        _expectAa(scheme.secondary, scheme.onSecondary, 'onSecondary');
        _expectAa(
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          'onSecondaryContainer',
        );
        _expectAa(scheme.tertiary, scheme.onTertiary, 'onTertiary');
        _expectAa(
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          'onTertiaryContainer',
        );
      });

      test('$label — error and surface on-colours clear AA', () {
        _expectAa(scheme.error, scheme.onError, 'onError');
        _expectAa(scheme.errorContainer, scheme.onErrorContainer, 'onErrorContainer');
        _expectAa(scheme.surface, scheme.onSurface, 'onSurface');
        _expectAa(
          scheme.surfaceContainerHighest,
          scheme.onSurface,
          'onSurface over surfaceContainerHighest',
        );
        _expectAa(scheme.inverseSurface, scheme.onInverseSurface, 'onInverseSurface');
      });

      test('$label — cuisine accents clear AA', () {
        final CuisineAccents accents = theme.extension<CuisineAccents>()!;
        for (int i = 0; i < accents.slots.length; i++) {
          _expectAa(
            accents[i].container,
            accents[i].onContainer,
            'cuisine accent $i',
          );
        }
      });
    }
  }
}

void _expectAa(Color background, Color foreground, String role) {
  final double ratio = _contrastRatio(background, foreground);
  expect(
    ratio,
    greaterThanOrEqualTo(_aaNormalText - _epsilon),
    reason: '$role has contrast ${ratio.toStringAsFixed(2)}:1, below AA',
  );
}

double _contrastRatio(Color a, Color b) {
  final double la = _relativeLuminance(a);
  final double lb = _relativeLuminance(b);
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  // Flutter's wide-gamut Color exposes linear sRGB channels as 0..1 doubles;
  // apply the WCAG 2.x transfer function to each before weighting.
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
