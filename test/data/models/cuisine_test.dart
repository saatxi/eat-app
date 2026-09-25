import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/data/models/cuisine.dart';
import 'package:eatapp/data/models/restaurant_sort.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cuisine', () {
    test('every entry round-trips through its own key', () {
      final Set<String> keys = <String>{};
      for (final Cuisine cuisine in Cuisine.values) {
        expect(keys.add(cuisine.key), isTrue, reason: 'duplicate key');
        expect(Cuisine.fromKey(cuisine.key), cuisine);
      }
      expect(keys.length, Cuisine.values.length);
    });

    test('resolves keys case- and whitespace-insensitively', () {
      expect(Cuisine.fromKey('  Mediterranean '), Cuisine.mediterranean);
      expect(Cuisine.fromKey('FINE_DINING'), Cuisine.fineDining);
    });

    test('returns null for a key this build does not know', () {
      expect(Cuisine.fromKey('fusion'), isNull);
      expect(Cuisine.fromKey(''), isNull);
      expect(Cuisine.fromKey(null), isNull);
    });

    test('labels each cuisine in the active locale', () {
      expect(
        Cuisine.italian.label(lookupAppLocalizations(const Locale('en'))),
        'Italian',
      );
      expect(
        Cuisine.italian.label(lookupAppLocalizations(const Locale('es'))),
        'Italiana',
      );
      expect(
        Cuisine.middleEastern.label(lookupAppLocalizations(const Locale('ca'))),
        'Orient Mitjà',
      );
    });
  });

  group('RestaurantSort', () {
    test('offers name first, then rating', () {
      expect(RestaurantSort.selectable, <RestaurantSort>[
        RestaurantSort.name,
        RestaurantSort.rating,
      ]);
    });
  });
}
