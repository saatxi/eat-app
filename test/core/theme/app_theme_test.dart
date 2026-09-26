import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/core/theme/app_theme_mode.dart';
import 'package:eatapp/core/theme/palettes/verd_palette.dart';
import 'package:eatapp/core/theme/tokens/app_typography.dart';
import 'package:eatapp/core/theme/tokens/cuisine_accents.dart';
import 'package:eatapp/core/theme/tokens/palette_tones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Brightness> _bothBrightnesses = <Brightness>[
  Brightness.light,
  Brightness.dark,
];

void main() {
  group('tokens', () {
    test('the palette defines exactly the required number of accents', () {
      expect(verdTones.accents.length, cuisineAccentCount);
    });

    test('cuisine accents wrap, so any index is valid', () {
      final CuisineAccents accents = CuisineAccents.light(verdTones);
      expect(accents[0].container, accents[cuisineAccentCount].container);
      expect(
        accents[cuisineAccentCount + 3].container,
        accents[3].container,
      );
    });

    test('display styles use the serif and body styles the sans', () {
      final TextTheme text = AppTypography.textTheme;
      expect(text.displayLarge!.fontFamily, AppTypography.displayFamily);
      expect(text.headlineLarge!.fontFamily, AppTypography.displayFamily);
      expect(text.titleLarge!.fontFamily, AppTypography.displayFamily);
      expect(text.bodyLarge!.fontFamily, AppTypography.bodyFamily);
      expect(text.labelLarge!.fontFamily, AppTypography.bodyFamily);
    });

    test('the variable serif carries weight and optical-size variations', () {
      final TextStyle display = AppTypography.textTheme.displayLarge!;
      final Map<String, double> axes = <String, double>{
        for (final FontVariation variation in display.fontVariations!)
          variation.axis: variation.value,
      };
      expect(axes.keys, containsAll(<String>['wght', 'opsz']));
      expect(axes['wght'], 400);
      expect(axes['opsz'], 57);
    });
  });

  group('theme mode', () {
    test('theme mode resolves its brightness and falls back safely', () {
      expect(AppThemeMode.light.brightness, Brightness.light);
      expect(AppThemeMode.dark.brightness, Brightness.dark);
      expect(AppThemeMode.fromId('dark'), AppThemeMode.dark);
      expect(AppThemeMode.fromId('nope'), AppThemeMode.fallback);
    });
  });

  group('AppTheme', () {
    test('publishes the cuisine accents as a theme extension', () {
      for (final Brightness brightness in _bothBrightnesses) {
        final ThemeData theme = AppTheme.build(verdTones, brightness);
        final CuisineAccents? accents = theme.extension<CuisineAccents>();
        expect(accents, isNotNull, reason: '$brightness');
        expect(accents!.slots.length, cuisineAccentCount);
      }
    });

    test('is Material 3 and matches the requested brightness', () {
      for (final Brightness brightness in _bothBrightnesses) {
        final ThemeData theme = AppTheme.build(verdTones, brightness);
        expect(theme.useMaterial3, isTrue);
        expect(theme.colorScheme.brightness, brightness);
        expect(theme.textTheme.displayLarge, isNotNull);
      }
    });

    test('light and dark accents swap the container and on-colour', () {
      final CuisineAccents light = CuisineAccents.light(verdTones);
      final CuisineAccents dark = CuisineAccents.dark(verdTones);
      expect(light[0].container, verdTones.accents[0].t90);
      expect(light[0].onContainer, verdTones.accents[0].t10);
      expect(dark[0].container, verdTones.accents[0].t30);
      expect(dark[0].onContainer, verdTones.accents[0].t90);
    });
  });
}
