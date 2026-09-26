import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/widget/home_widget_snapshot.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db/db_test_utils.dart';

void main() {
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

  group('buildHomeWidgetSnapshot', () {
    test('is empty when nothing is want-to-try', () {
      final HomeWidgetSnapshot snapshot = buildHomeWidgetSnapshot(
        restaurant: null,
        l10n: l10n,
      );

      expect(snapshot.hasRestaurant, isFalse);
      expect(snapshot.restaurantId, isEmpty);
      expect(snapshot.title, isEmpty);
      expect(snapshot.subtitle, isEmpty);
    });

    test('carries the id, the name and the translated cuisine', () {
      final HomeWidgetSnapshot snapshot = buildHomeWidgetSnapshot(
        restaurant: restaurant(id: 'a', name: 'Cal Ferran', cuisineType: 'catalan'),
        l10n: l10n,
      );

      expect(snapshot.hasRestaurant, isTrue);
      expect(snapshot.restaurantId, 'a');
      expect(snapshot.title, 'Cal Ferran');
      expect(snapshot.subtitle, 'Catalan');
    });

    test('appends the town to the cuisine when one is set', () {
      final HomeWidgetSnapshot snapshot = buildHomeWidgetSnapshot(
        restaurant: restaurant(
          id: 'a',
          name: 'Cal Ferran',
          cuisineType: 'catalan',
          city: 'Barcelona',
        ),
        l10n: l10n,
      );

      expect(snapshot.subtitle, 'Catalan · Barcelona');
    });

    test('ignores a blank town rather than printing a dangling separator', () {
      final HomeWidgetSnapshot snapshot = buildHomeWidgetSnapshot(
        restaurant: restaurant(
          id: 'a',
          name: 'Cal Ferran',
          cuisineType: 'italian',
          city: '   ',
        ),
        l10n: l10n,
      );

      expect(snapshot.subtitle, 'Italian');
    });

    test('falls back to the raw cuisine key for one this build does not know', () {
      final HomeWidgetSnapshot snapshot = buildHomeWidgetSnapshot(
        restaurant: restaurant(id: 'a', name: 'X', cuisineType: 'martian'),
        l10n: l10n,
      );

      expect(snapshot.subtitle, 'martian');
    });
  });

  group('homeWidgetRestaurantId', () {
    test('reads the id back out of the link the widget opens with', () {
      expect(
        homeWidgetRestaurantId(homeWidgetRestaurantLink('abc-123')),
        'abc-123',
      );
    });

    test('rejects the shuffle link', () {
      expect(homeWidgetRestaurantId(homeWidgetShuffleLink), isNull);
    });

    test('rejects a foreign scheme or host', () {
      expect(
        homeWidgetRestaurantId(Uri.parse('https://restaurant/abc')),
        isNull,
      );
      expect(homeWidgetRestaurantId(Uri.parse('eatapp://elsewhere/abc')), isNull);
    });

    test('rejects a link carrying no id, and a missing one', () {
      expect(homeWidgetRestaurantId(Uri.parse('eatapp://restaurant')), isNull);
      expect(homeWidgetRestaurantId(null), isNull);
    });
  });
}
