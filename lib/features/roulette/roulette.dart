import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';

/// The roulette screen's own filters, applied on top of the shared list query.
///
/// `minRating`, `visited`, `cuisineType`, `city`, `region` and `country` are
/// pushed into SQL, because the visits table has to be consulted for the first
/// two and the rest are plain column compares against the shared list query;
/// `favoritesOnly` and `priceRange` are applied here instead, since favourites
/// live in the preference file rather than the database.
///
/// Deliberately the same dimensions the restaurants list offers, so "which
/// places can a spin land on?" is answered the same way as "which places does
/// the list show?".
@immutable
class RouletteFilters {
  const RouletteFilters({
    this.minRating,
    this.favoritesOnly = false,
    this.visited,
    this.priceRange,
    this.cuisineType,
    this.city,
    this.region,
    this.country,
  });

  /// Minimum rating a visit has to reach. Null means no rating filter.
  final int? minRating;

  final bool favoritesOnly;

  /// Null means either; true means already visited, false means want-to-try.
  final bool? visited;

  final int? priceRange;

  final String? cuisineType;
  final String? city;
  final String? region;
  final String? country;

  /// The `with…` methods exist instead of a `copyWith`, because every field
  /// here is nullable for a reason — clearing one is a real operation, and a
  /// `copyWith` that can't tell "leave it" from "clear it" would silently make
  /// that impossible.
  RouletteFilters withMinRating(int? value) => RouletteFilters(
    minRating: value,
    favoritesOnly: favoritesOnly,
    visited: visited,
    priceRange: priceRange,
    cuisineType: cuisineType,
    city: city,
    region: region,
    country: country,
  );

  RouletteFilters withFavoritesOnly(bool value) => RouletteFilters(
    minRating: minRating,
    favoritesOnly: value,
    visited: visited,
    priceRange: priceRange,
    cuisineType: cuisineType,
    city: city,
    region: region,
    country: country,
  );

  RouletteFilters withVisited(bool? value) => RouletteFilters(
    minRating: minRating,
    favoritesOnly: favoritesOnly,
    visited: value,
    priceRange: priceRange,
    cuisineType: cuisineType,
    city: city,
    region: region,
    country: country,
  );

  RouletteFilters withPriceRange(int? value) => RouletteFilters(
    minRating: minRating,
    favoritesOnly: favoritesOnly,
    visited: visited,
    priceRange: value,
    cuisineType: cuisineType,
    city: city,
    region: region,
    country: country,
  );

  RouletteFilters withCuisineType(String? value) => RouletteFilters(
    minRating: minRating,
    favoritesOnly: favoritesOnly,
    visited: visited,
    priceRange: priceRange,
    cuisineType: value,
    city: city,
    region: region,
    country: country,
  );

  RouletteFilters withCity(String? value) => RouletteFilters(
    minRating: minRating,
    favoritesOnly: favoritesOnly,
    visited: visited,
    priceRange: priceRange,
    cuisineType: cuisineType,
    city: value,
    region: region,
    country: country,
  );

  RouletteFilters withRegion(String? value) => RouletteFilters(
    minRating: minRating,
    favoritesOnly: favoritesOnly,
    visited: visited,
    priceRange: priceRange,
    cuisineType: cuisineType,
    city: city,
    region: value,
    country: country,
  );

  RouletteFilters withCountry(String? value) => RouletteFilters(
    minRating: minRating,
    favoritesOnly: favoritesOnly,
    visited: visited,
    priceRange: priceRange,
    cuisineType: cuisineType,
    city: city,
    region: region,
    country: value,
  );
}

/// The restaurants a spin can land on.
///
/// [restaurants] is the result of the shared list query with this screen's
/// SQL-side filters already applied — the roulette deliberately reuses that
/// query rather than adding one of its own, so there is a single definition of
/// what "matches" means across the app.
///
/// The order is the query's own, which matters: [pickRouletteCandidate] indexes
/// into it, so a stable order is what makes a seeded random source reproducible.
List<Restaurant> rouletteCandidates({
  required List<Restaurant> restaurants,
  required RouletteFilters filters,
  required Set<String> favoriteIds,
}) => <Restaurant>[
  for (final Restaurant restaurant in restaurants)
    if ((!filters.favoritesOnly || favoriteIds.contains(restaurant.id)) &&
        (filters.priceRange == null ||
            restaurant.priceRange == filters.priceRange))
      restaurant,
];

/// One restaurant at random, or null when there is nothing to pick from.
///
/// [random] is a parameter so a test can seed it and assert a deterministic
/// outcome.
Restaurant? pickRouletteCandidate(
  List<Restaurant> candidates,
  Random random,
) => candidates.isEmpty ? null : candidates[random.nextInt(candidates.length)];

/// Keeps [picked] only while it is still a candidate.
///
/// Once a filter change moves the picked restaurant out of the pool, the screen
/// has to fall back to its "spin" prompt — showing a restaurant that no longer
/// matches the filters would be worse than showing nothing.
Restaurant? retainCandidate(Restaurant? picked, List<Restaurant> candidates) {
  if (picked == null) {
    return null;
  }
  for (final Restaurant candidate in candidates) {
    if (candidate.id == picked.id) {
      return picked;
    }
  }
  return null;
}
