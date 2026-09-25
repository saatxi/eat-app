import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/widgets/cuisine_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  group('cuisineLabel', () {
    test('translates a known key', () {
      expect(cuisineLabel(en, 'mediterranean'), 'Mediterranean');
      expect(cuisineLabel(en, 'fast_food'), 'Fast food');
    });

    test('keeps an unknown key verbatim', () {
      expect(cuisineLabel(en, 'martian'), 'martian');
    });
  });

  group('cuisineIcon', () {
    test('gives each known key its own icon', () {
      expect(cuisineIcon('italian'), Icons.local_pizza);
      expect(cuisineIcon('japanese'), Icons.ramen_dining);
      expect(cuisineIcon('vegetarian'), Icons.grass);
    });

    test('falls back to a generic icon for an unknown key', () {
      expect(cuisineIcon('martian'), Icons.restaurant);
    });
  });
}
