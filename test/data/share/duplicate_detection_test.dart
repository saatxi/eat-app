import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

void main() {
  group('isLikelyDuplicateOf', () {
    test('matches on the same name, ignoring case and surrounding space', () {
      final Restaurant a = restaurant(id: '1', name: ' Cal Ferran ');
      final Restaurant b = restaurant(id: '2', name: 'cal ferran');
      expect(isLikelyDuplicateOf(a, b), isTrue);
    });

    test('matches when only one side records an address', () {
      final Restaurant withAddress = restaurant(
        id: '1',
        name: 'Cal Ferran',
        streetAddress: 'Plaça Santa Anna',
      );
      final Restaurant withoutAddress = restaurant(id: '2', name: 'Cal Ferran');
      expect(isLikelyDuplicateOf(withAddress, withoutAddress), isTrue);
    });

    test('does not match when both have different addresses', () {
      final Restaurant a = restaurant(
        id: '1',
        name: 'Cal Ferran',
        streetAddress: 'Carrer Nou',
      );
      final Restaurant b = restaurant(
        id: '2',
        name: 'Cal Ferran',
        streetAddress: 'Plaça Santa Anna',
      );
      expect(isLikelyDuplicateOf(a, b), isFalse);
    });

    test('does not match restaurants that only share an address', () {
      final Restaurant a = restaurant(
        id: '1',
        name: 'Cal Ferran',
        streetAddress: 'Plaça Santa Anna',
      );
      final Restaurant b = restaurant(
        id: '2',
        name: 'La Taverna',
        streetAddress: 'Plaça Santa Anna',
      );
      expect(isLikelyDuplicateOf(a, b), isFalse);
    });
  });
}
