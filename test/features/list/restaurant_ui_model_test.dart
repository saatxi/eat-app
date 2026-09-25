import 'package:eatapp/features/list/restaurant_ui_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';

void main() {
  group('the latest visit', () {
    test('supplies the rating, the visited flag and the notes', () {
      final RestaurantUiModel model = restaurant(id: 'a', name: 'Kebab')
          .toUiModel(
            latestVisit: visit(
              id: 'v',
              restaurantId: 'a',
              visitDate: 1,
              rating: 4,
              notes: 'Bones',
            ),
          );

      expect(model.rating, 4);
      expect(model.visited, isTrue);
      expect(model.notes, 'Bones');
    });

    test('leaves a restaurant with no visits unrated and unvisited', () {
      final RestaurantUiModel model = restaurant(id: 'a', name: 'Kebab')
          .toUiModel();

      expect(model.rating, 0);
      expect(model.visited, isFalse);
      expect(model.notes, isNull);
    });

    test('drops a blank note instead of drawing an empty card', () {
      final RestaurantUiModel model = restaurant(id: 'a', name: 'Kebab')
          .toUiModel(
            latestVisit: visit(
              id: 'v',
              restaurantId: 'a',
              visitDate: 1,
              rating: 3,
              notes: '   ',
            ),
          );

      expect(model.notes, isNull);
    });
  });

  group('the address', () {
    test('treats a present-but-blank component as absent', () {
      final RestaurantUiModel model = restaurant(
        id: 'a',
        name: 'Kebab',
        streetAddress: '  ',
        city: 'Barcelona',
      ).toUiModel();

      expect(model.streetAddress, isNull);
      expect(model.city, 'Barcelona');
      expect(model.formattedAddress, 'Barcelona');
    });

    test('is null when no component has anything in it', () {
      final RestaurantUiModel model = restaurant(
        id: 'a',
        name: 'Kebab',
        city: '  ',
      ).toUiModel();

      expect(model.formattedAddress, isNull);
    });

    test('joins the components that do have something', () {
      final RestaurantUiModel model = restaurant(
        id: 'a',
        name: 'Kebab',
        streetAddress: 'Carrer Major 1',
        city: 'Girona',
        country: 'Espanya',
      ).toUiModel();

      expect(model.formattedAddress, 'Carrer Major 1, Girona, Espanya');
    });
  });

  group('the price band', () {
    test('is carried through inside the picker scale', () {
      expect(restaurant(id: 'a', name: 'Kebab', priceRange: 3).toUiModel().priceRange, 3);
    });

    test('is clamped, so a hand-built row cannot draw outside the scale', () {
      expect(
        restaurant(id: 'a', name: 'Kebab', priceRange: maxPriceRange + 3)
            .toUiModel()
            .priceRange,
        maxPriceRange,
      );
      expect(
        restaurant(id: 'a', name: 'Kebab', priceRange: -2).toUiModel().priceRange,
        0,
      );
    });
  });

  group('the tags', () {
    test('are joined for drawing and split back apart for the widgets', () {
      final RestaurantUiModel model = restaurant(id: 'a', name: 'Kebab')
          .toUiModel(tags: <String>['Terraza', 'Coeliac']);

      expect(model.tagsLabel, 'Terraza, Coeliac');
      expect(model.tags, <String>['Terraza', 'Coeliac']);
    });

    test('leave both the label and the list empty when there are none', () {
      final RestaurantUiModel model = restaurant(id: 'a', name: 'Kebab')
          .toUiModel();

      expect(model.tagsLabel, '');
      expect(model.tags, isEmpty);
    });
  });

  group('the links', () {
    test('count as present only when there is at least one', () {
      expect(restaurant(id: 'a', name: 'Kebab').toUiModel().hasLinks, isFalse);
      expect(
        restaurant(id: 'a', name: 'Kebab', instagram: 'kebab').toUiModel().hasLinks,
        isTrue,
      );
    });
  });

  test('two rows built from the same data are equal, and one differing field is not', () {
    final RestaurantUiModel one = restaurant(id: 'a', name: 'Kebab').toUiModel(
      isFavorite: true,
      tags: <String>['Terraza'],
      latestVisit: visit(
        id: 'v',
        restaurantId: 'a',
        visitDate: 1,
        rating: 4,
      ),
    );
    final RestaurantUiModel same = restaurant(id: 'a', name: 'Kebab').toUiModel(
      isFavorite: true,
      tags: <String>['Terraza'],
      latestVisit: visit(
        id: 'v',
        restaurantId: 'a',
        visitDate: 1,
        rating: 4,
      ),
    );

    expect(one, same);
    expect(one.hashCode, same.hashCode);
    expect(one, isNot(restaurant(id: 'a', name: 'Sushi').toUiModel()));
  });
}
