import 'dart:convert';

import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/share/restaurant_import_reader.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:eatapp/data/share/restaurant_share_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// A share file built by hand, so a malformed row can be injected without
/// going through the writer under test.
String _file(List<Object?> restaurants) => jsonEncode(<String, Object?>{
  'format': restaurantShareFormat,
  'restaurants': restaurants,
});

void main() {
  group('the share file round-trips', () {
    test('a restaurant with its tags, visits and normalised links', () {
      final Restaurant source = restaurant(
        id: 'a',
        name: 'Cal Ferran',
        cuisineType: 'mediterranean',
        streetAddress: 'Plaça Santa Anna',
        priceRange: 2,
        website: 'example.com',
        instagram: '@calferran',
        city: 'Mataró',
        region: 'Catalunya',
        country: 'Espanya',
      );
      final List<RestaurantExport> exports = <RestaurantExport>[
        exportRestaurant(
          source,
          tags: const <String>['Terraza'],
          visits: <Visit>[
            visit(
              id: 'v',
              restaurantId: 'a',
              visitDate: 1000,
              rating: 4,
              notes: 'bona',
              priceRange: 2,
            ),
          ],
        ),
      ];

      final ImportOutcome outcome = readRestaurantImport(
        encodeRestaurantShareFile(exports),
      );

      expect(outcome, isA<ImportSuccess>());
      final ImportSuccess success = outcome as ImportSuccess;
      expect(success.skippedCount, 0);
      final ImportedRestaurant imported = success.restaurants.single;
      // A fresh id, never the source's.
      expect(imported.restaurant.id, isNotEmpty);
      expect(imported.restaurant.id, isNot('a'));
      expect(imported.restaurant.name, 'Cal Ferran');
      expect(imported.restaurant.cuisineType, 'mediterranean');
      expect(imported.restaurant.streetAddress, 'Plaça Santa Anna');
      expect(imported.restaurant.priceRange, 2);
      // Both links go through the same whitelist the edit form uses.
      expect(imported.restaurant.website, 'https://example.com');
      expect(imported.restaurant.instagram, 'calferran');
      expect(imported.tags, <String>['Terraza']);
      expect(imported.visits.single.rating, 4);
      expect(imported.visits.single.notes, 'bona');
      expect(imported.visits.single.priceRange, 2);
    });

    test('every field is written, including the ones left at their default', () {
      final Map<String, Object?> json =
          jsonDecode(encodeRestaurantShareFile(<RestaurantExport>[
                exportRestaurant(restaurant(id: 'a', name: 'Plain')),
              ]))
              as Map<String, Object?>;

      expect(json['format'], restaurantShareFormat);
      final Map<String, Object?> row =
          (json['restaurants']! as List<Object?>).single! as Map<String, Object?>;
      expect(row.containsKey('streetAddress'), isTrue);
      expect(row['streetAddress'], isNull);
      expect(row['tags'], isEmpty);
      expect(row['visits'], isEmpty);
    });
  });

  group('the import reader rejects a whole file', () {
    test('when the bytes are not JSON', () {
      expect(
        readRestaurantImport('not json at all'),
        isA<ImportError>().having(
          (ImportError e) => e.reason,
          'reason',
          ImportFailureReason.invalidFile,
        ),
      );
    });

    test('when the top level is not an object', () {
      expect(readRestaurantImport('[1,2,3]'), isA<ImportError>());
    });

    test('when the format marker is missing or foreign', () {
      expect(
        readRestaurantImport(jsonEncode(<String, Object?>{'restaurants': <Object?>[]})),
        isA<ImportError>(),
      );
      expect(
        readRestaurantImport(
          jsonEncode(<String, Object?>{
            'format': 'someone.else.v1',
            'restaurants': <Object?>[],
          }),
        ),
        isA<ImportError>(),
      );
    });

    test('when restaurants is not a list', () {
      expect(
        readRestaurantImport(
          jsonEncode(<String, Object?>{
            'format': restaurantShareFormat,
            'restaurants': 'nope',
          }),
        ),
        isA<ImportError>(),
      );
    });
  });

  group('the import reader skips a bad row without failing the file', () {
    test('counting every dropped row', () {
      final ImportOutcome outcome = readRestaurantImport(
        _file(<Object?>[
          <String, Object?>{'name': 'Good', 'cuisineType': 'italian', 'priceRange': 1},
          // Missing the required name.
          <String, Object?>{'cuisineType': 'italian', 'priceRange': 1},
          // Out-of-range price band.
          <String, Object?>{'name': 'Bad price', 'cuisineType': 'italian', 'priceRange': 9},
          // Not even an object.
          'nope',
        ]),
      );

      final ImportSuccess success = outcome as ImportSuccess;
      expect(success.restaurants.single.restaurant.name, 'Good');
      expect(success.skippedCount, 3);
    });

    test('dropping a restaurant whose one visit is out of range', () {
      final ImportOutcome outcome = readRestaurantImport(
        _file(<Object?>[
          <String, Object?>{
            'name': 'Bad visit',
            'cuisineType': 'italian',
            'priceRange': 1,
            'visits': <Object?>[
              <String, Object?>{'visitDate': 1, 'rating': 9},
            ],
          },
        ]),
      );

      final ImportSuccess success = outcome as ImportSuccess;
      expect(success.restaurants, isEmpty);
      expect(success.skippedCount, 1);
    });

    test('validating tags the same per-item-lenient way the form does', () {
      final ImportOutcome outcome = readRestaurantImport(
        _file(<Object?>[
          <String, Object?>{
            'name': 'Tagged',
            'cuisineType': 'italian',
            'priceRange': 1,
            'tags': <Object?>['Terraza', 'terraza', 'bad,tag', '', '  '],
          },
        ]),
      );

      final ImportSuccess success = outcome as ImportSuccess;
      expect(success.restaurants.single.tags, <String>['Terraza']);
    });

    test('dropping an unsafe website rather than passing it through', () {
      final ImportOutcome outcome = readRestaurantImport(
        _file(<Object?>[
          <String, Object?>{
            'name': 'Sneaky',
            'cuisineType': 'italian',
            'priceRange': 1,
            'website': 'javascript:alert(1)',
          },
        ]),
      );

      final ImportSuccess success = outcome as ImportSuccess;
      expect(success.restaurants.single.restaurant.website, isNull);
    });
  });

  group('restaurantNameSlug', () {
    test('lowercases and folds everything that is not a letter or digit', () {
      expect(restaurantNameSlug('Cal Ferran!'), 'cal-ferran');
      expect(restaurantNameSlug('  A  B  '), 'a-b');
    });

    test('keeps accents, so Cafè stays reachable', () {
      expect(restaurantNameSlug('Cafè'), 'cafè');
    });

    test('caps a very long name and falls back when nothing survives', () {
      expect(restaurantNameSlug('x' * 200).length, 60);
      expect(restaurantNameSlug('!!!'), 'restaurant');
      expect(restaurantNameSlug(''), 'restaurant');
    });
  });
}
