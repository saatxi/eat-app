import 'dart:math';

import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/features/roulette/roulette.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';

void main() {
  final Restaurant first = restaurant(id: 'a', name: 'First', priceRange: 0);
  final Restaurant second = restaurant(id: 'b', name: 'Second', priceRange: 3);
  final Restaurant third = restaurant(id: 'c', name: 'Third', priceRange: 3);
  final List<Restaurant> all = <Restaurant>[first, second, third];

  List<String> idsOf(List<Restaurant> restaurants) =>
      <String>[for (final Restaurant r in restaurants) r.id];

  group('rouletteCandidates', () {
    test('with nothing filtered, every restaurant is a candidate', () {
      final List<Restaurant> candidates = rouletteCandidates(
        restaurants: all,
        filters: const RouletteFilters(),
        favoriteIds: const <String>{},
      );

      expect(idsOf(candidates), <String>['a', 'b', 'c']);
    });

    test('favoritesOnly keeps only the favourites', () {
      final List<Restaurant> candidates = rouletteCandidates(
        restaurants: all,
        filters: const RouletteFilters(favoritesOnly: true),
        favoriteIds: const <String>{'b'},
      );

      expect(idsOf(candidates), <String>['b']);
    });

    test('favoritesOnly with nothing favourited leaves nothing to spin', () {
      final List<Restaurant> candidates = rouletteCandidates(
        restaurants: all,
        filters: const RouletteFilters(favoritesOnly: true),
        favoriteIds: const <String>{},
      );

      expect(candidates, isEmpty);
    });

    test('a price range of 0 is a real band, not "no filter"', () {
      final List<Restaurant> candidates = rouletteCandidates(
        restaurants: all,
        filters: const RouletteFilters(priceRange: 0),
        favoriteIds: const <String>{},
      );

      expect(idsOf(candidates), <String>['a']);
    });

    test('favoritesOnly and a price range have to both hold', () {
      final List<Restaurant> candidates = rouletteCandidates(
        restaurants: all,
        filters: const RouletteFilters(favoritesOnly: true, priceRange: 3),
        favoriteIds: const <String>{'b', 'c'},
      );

      expect(idsOf(candidates), <String>['b', 'c']);
    });

    test('keeps the order it was given, old and new filters alike', () {
      final List<Restaurant> reversed = all.reversed.toList();

      expect(
        idsOf(
          rouletteCandidates(
            restaurants: reversed,
            filters: const RouletteFilters(priceRange: 3),
            favoriteIds: const <String>{},
          ),
        ),
        <String>['c', 'b'],
        reason: 'a stable pool is what makes a seeded pick reproducible',
      );
    });
  });

  group('pickRouletteCandidate', () {
    test('is null when there is nothing to pick from', () {
      expect(pickRouletteCandidate(const <Restaurant>[], Random(1)), isNull);
    });

    test('the same seed picks the same restaurant every time', () {
      final Restaurant? firstPick = pickRouletteCandidate(all, Random(7));
      final Restaurant? secondPick = pickRouletteCandidate(all, Random(7));

      expect(firstPick, isNotNull);
      expect(firstPick!.id, secondPick!.id);
    });

    test('over many spins, every candidate comes up', () {
      final Random random = Random(3);
      final Set<String> seen = <String>{};
      for (int spin = 0; spin < 200; spin++) {
        seen.add(pickRouletteCandidate(all, random)!.id);
      }

      expect(seen, <String>{'a', 'b', 'c'});
    });

    test('a single candidate is always the one picked', () {
      expect(
        pickRouletteCandidate(<Restaurant>[second], Random(9))!.id,
        'b',
      );
    });
  });

  group('retainCandidate', () {
    test('keeps the pick while it is still a candidate', () {
      expect(retainCandidate(second, all), second);
    });

    test('drops the pick once a filter moves it out of the pool', () {
      expect(
        retainCandidate(second, <Restaurant>[first, third]),
        isNull,
        reason: 'showing a restaurant that no longer matches is worse than none',
      );
    });

    test('a pool that shrank to nothing drops the pick too', () {
      expect(retainCandidate(second, const <Restaurant>[]), isNull);
    });

    test('nothing picked stays nothing picked', () {
      expect(retainCandidate(null, all), isNull);
    });

    test('it compares ids, not object identity', () {
      final Restaurant sameRestaurant = restaurant(id: 'b', name: 'Second');

      expect(retainCandidate(sameRestaurant, all), sameRestaurant);
    });
  });

  group('RouletteFilters', () {
    test('each with… changes exactly one field', () {
      const RouletteFilters filters = RouletteFilters(
        minRating: 4,
        favoritesOnly: true,
        visited: false,
        priceRange: 2,
      );

      final RouletteFilters rated = filters.withMinRating(5);
      expect(rated.minRating, 5);
      expect(rated.favoritesOnly, isTrue);
      expect(rated.visited, isFalse);
      expect(rated.priceRange, 2);

      final RouletteFilters favourite = filters.withFavoritesOnly(false);
      expect(favourite.favoritesOnly, isFalse);
      expect(favourite.minRating, 4);

      final RouletteFilters visited = filters.withVisited(true);
      expect(visited.visited, isTrue);
      expect(visited.priceRange, 2);

      final RouletteFilters priced = filters.withPriceRange(6);
      expect(priced.priceRange, 6);
      expect(priced.minRating, 4);
    });

    test('a nullable filter can be cleared back to "no filter"', () {
      const RouletteFilters filters = RouletteFilters(
        minRating: 4,
        visited: true,
        priceRange: 2,
      );

      expect(filters.withMinRating(null).minRating, isNull);
      expect(filters.withVisited(null).visited, isNull);
      expect(filters.withPriceRange(null).priceRange, isNull);
    });
  });
}
