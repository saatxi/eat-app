import 'package:flutter/foundation.dart';

import '../../data/models/restaurant_sort.dart';

/// Every input the list query is built from, in one immutable bundle.
///
/// It exists so the nine values travel together: the controller keeps one of
/// these as its only mutable state, hands it to `observeFiltered` in one call,
/// and each screen widget changes exactly one field through the matching
/// `with…` method. That last part is why there is no `copyWith` here — six of
/// the nine fields are nullable, and a `copyWith` cannot tell "leave this one
/// alone" from "clear it", which is a distinction every one of those setters
/// needs (clearing the cuisine filter and never having set one are different
/// user actions that have to reach the query as the same value).
@immutable
class RestaurantFilters {
  const RestaurantFilters({
    this.query = '',
    this.minRating,
    this.cuisineType,
    this.visited,
    this.sort = RestaurantSort.name,
    this.city,
    this.region,
    this.country,
    this.priceRange,
  });

  /// As typed. Folding and escaping happen in the repository, not here.
  final String query;
  final int? minRating;
  final String? cuisineType;
  final bool? visited;

  /// Not a filter in the "narrows the list down" sense — it rides along here
  /// because it is the fifth input the query is built from.
  final RestaurantSort sort;

  final String? city;
  final String? region;
  final String? country;
  final int? priceRange;

  RestaurantFilters withQuery(String value) => RestaurantFilters(
    query: value,
    minRating: minRating,
    cuisineType: cuisineType,
    visited: visited,
    sort: sort,
    city: city,
    region: region,
    country: country,
    priceRange: priceRange,
  );

  RestaurantFilters withMinRating(int? value) => RestaurantFilters(
    query: query,
    minRating: value,
    cuisineType: cuisineType,
    visited: visited,
    sort: sort,
    city: city,
    region: region,
    country: country,
    priceRange: priceRange,
  );

  RestaurantFilters withCuisineType(String? value) => RestaurantFilters(
    query: query,
    minRating: minRating,
    cuisineType: value,
    visited: visited,
    sort: sort,
    city: city,
    region: region,
    country: country,
    priceRange: priceRange,
  );

  RestaurantFilters withVisited(bool? value) => RestaurantFilters(
    query: query,
    minRating: minRating,
    cuisineType: cuisineType,
    visited: value,
    sort: sort,
    city: city,
    region: region,
    country: country,
    priceRange: priceRange,
  );

  RestaurantFilters withSort(RestaurantSort value) => RestaurantFilters(
    query: query,
    minRating: minRating,
    cuisineType: cuisineType,
    visited: visited,
    sort: value,
    city: city,
    region: region,
    country: country,
    priceRange: priceRange,
  );

  RestaurantFilters withCity(String? value) => RestaurantFilters(
    query: query,
    minRating: minRating,
    cuisineType: cuisineType,
    visited: visited,
    sort: sort,
    city: value,
    region: region,
    country: country,
    priceRange: priceRange,
  );

  RestaurantFilters withRegion(String? value) => RestaurantFilters(
    query: query,
    minRating: minRating,
    cuisineType: cuisineType,
    visited: visited,
    sort: sort,
    city: city,
    region: value,
    country: country,
    priceRange: priceRange,
  );

  RestaurantFilters withCountry(String? value) => RestaurantFilters(
    query: query,
    minRating: minRating,
    cuisineType: cuisineType,
    visited: visited,
    sort: sort,
    city: city,
    region: region,
    country: value,
    priceRange: priceRange,
  );

  RestaurantFilters withPriceRange(int? value) => RestaurantFilters(
    query: query,
    minRating: minRating,
    cuisineType: cuisineType,
    visited: visited,
    sort: sort,
    city: city,
    region: region,
    country: country,
    priceRange: value,
  );

  /// Drops every narrowing input and keeps the chosen order: it is reached from
  /// the "no matches" state, where the user wants their restaurants back, not
  /// their ordering undone.
  RestaurantFilters withoutFilters() => RestaurantFilters(sort: sort);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantFilters &&
          other.query == query &&
          other.minRating == minRating &&
          other.cuisineType == cuisineType &&
          other.visited == visited &&
          other.sort == sort &&
          other.city == city &&
          other.region == region &&
          other.country == country &&
          other.priceRange == priceRange;

  @override
  int get hashCode => Object.hash(
    query,
    minRating,
    cuisineType,
    visited,
    sort,
    city,
    region,
    country,
    priceRange,
  );

  @override
  String toString() =>
      'RestaurantFilters(query: "$query", minRating: $minRating, '
      'cuisine: $cuisineType, visited: $visited, sort: ${sort.name}, '
      'city: $city, region: $region, country: $country, price: $priceRange)';
}

/// The values each filter dimension can offer, read from the data itself rather
/// than from a hard-coded list: a city only appears once some restaurant is in
/// it, and disappears when the last one leaves.
///
/// Bundled into one object so the controller publishes them as a single
/// snapshot instead of four lists that can be seen half-updated.
@immutable
class AvailableFilterValues {
  const AvailableFilterValues({
    this.cuisines = const <String>[],
    this.cities = const <String>[],
    this.regions = const <String>[],
    this.countries = const <String>[],
  });

  final List<String> cuisines;
  final List<String> cities;
  final List<String> regions;
  final List<String> countries;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailableFilterValues &&
          listEquals(other.cuisines, cuisines) &&
          listEquals(other.cities, cities) &&
          listEquals(other.regions, regions) &&
          listEquals(other.countries, countries);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(cuisines),
    Object.hashAll(cities),
    Object.hashAll(regions),
    Object.hashAll(countries),
  );
}
