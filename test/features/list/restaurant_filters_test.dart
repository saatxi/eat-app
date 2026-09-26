import 'package:eatapp/data/models/restaurant_sort.dart';
import 'package:eatapp/features/list/restaurant_filters.dart';
import 'package:flutter_test/flutter_test.dart';

/// The filter bundle's own contract.
///
/// Nine fields travel together through a screen that changes one at a time, and
/// every setter rebuilds the whole object by hand. A setter that forgets to
/// carry one of the others would not fail to compile or throw — it would just
/// silently drop a filter — so the shape of the object is worth pinning down
/// here rather than only through the screen that drives it.
void main() {
  const RestaurantFilters everything = RestaurantFilters(
    query: 'ferran',
    minRating: 4,
    cuisineType: 'catalan',
    visited: false,
    sort: RestaurantSort.rating,
    city: 'Barcelona',
    region: 'Catalunya',
    country: 'Espanya',
    priceRange: 3,
  );

  /// The nine fields in declaration order. Kept in step with the class by the
  /// count asserted below: adding a field means adding it here too, which is
  /// what stops a new field from going unchecked.
  List<Object?> fieldsOf(RestaurantFilters filters) => <Object?>[
    filters.query,
    filters.minRating,
    filters.cuisineType,
    filters.visited,
    filters.sort,
    filters.city,
    filters.region,
    filters.country,
    filters.priceRange,
  ];

  /// Which positions differ between two bundles.
  List<int> differences(RestaurantFilters a, RestaurantFilters b) {
    final List<Object?> before = fieldsOf(a);
    final List<Object?> after = fieldsOf(b);
    return <int>[
      for (int i = 0; i < before.length; i++)
        if (before[i] != after[i]) i,
    ];
  }

  test('the field list covers every field', () {
    expect(fieldsOf(everything), hasLength(9));
  });

  test('each setter changes its own field and nothing else', () {
    final List<(String, int, RestaurantFilters)> cases =
        <(String, int, RestaurantFilters)>[
          ('withQuery', 0, everything.withQuery('marina')),
          ('withMinRating', 1, everything.withMinRating(2)),
          ('withCuisineType', 2, everything.withCuisineType('italian')),
          ('withVisited', 3, everything.withVisited(true)),
          ('withSort', 4, everything.withSort(RestaurantSort.name)),
          ('withCity', 5, everything.withCity('Girona')),
          ('withRegion', 6, everything.withRegion('Empordà')),
          ('withCountry', 7, everything.withCountry('França')),
          ('withPriceRange', 8, everything.withPriceRange(5)),
        ];

    for (final (String name, int field, RestaurantFilters next) in cases) {
      expect(
        differences(everything, next),
        <int>[field],
        reason: '$name must carry every other field through unchanged',
      );
    }
  });

  test('a setter can clear a field as well as set one', () {
    expect(everything.withCuisineType(null).cuisineType, isNull);
    expect(everything.withVisited(null).visited, isNull);
    expect(everything.withPriceRange(null).priceRange, isNull);
    expect(everything.withQuery('').query, isEmpty);
  });

  test('withoutFilters drops every filter and keeps the chosen order', () {
    final RestaurantFilters cleared = everything.withoutFilters();

    expect(differences(everything, cleared), <int>[0, 1, 2, 3, 5, 6, 7, 8]);
    expect(
      cleared.sort,
      RestaurantSort.rating,
      reason: 'the order is not a filter: the user asked for their '
          'restaurants back, not their ordering undone',
    );
  });

  test('equality tells a cleared field from an unset one', () {
    expect(const RestaurantFilters(minRating: 4), isNot(const RestaurantFilters()));
    expect(const RestaurantFilters(visited: false), isNot(const RestaurantFilters(visited: true)));
    expect(const RestaurantFilters(query: ''), const RestaurantFilters());
    expect(everything, everything.withQuery('ferran'));
  });

  group('AvailableFilterValues', () {
    test('compares by value, list contents included', () {
      expect(
        const AvailableFilterValues(
          cuisines: <String>['catalan'],
          cities: <String>['Barcelona'],
        ),
        const AvailableFilterValues(
          cuisines: <String>['catalan'],
          cities: <String>['Barcelona'],
        ),
      );
      expect(
        const AvailableFilterValues(cuisines: <String>['catalan']),
        isNot(const AvailableFilterValues(cuisines: <String>['italian'])),
      );
      expect(
        const AvailableFilterValues(cities: <String>['Barcelona']),
        isNot(const AvailableFilterValues(cities: <String>['Girona'])),
      );
    });

    test('an absent dimension is the same as an empty one', () {
      expect(
        const AvailableFilterValues(),
        const AvailableFilterValues(cuisines: <String>[]),
      );
    });
  });
}
