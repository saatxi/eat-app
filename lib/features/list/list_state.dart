import 'package:flutter/foundation.dart';

import '../../data/models/restaurant_sort.dart';
import 'restaurant_filters.dart';
import 'restaurant_ui_model.dart';

/// Everything the list screen draws, as one immutable snapshot.
///
/// It carries the active [filters] as a single object and re-exposes the fields
/// the screen reads directly, so a widget asks the state for what it needs
/// instead of reaching into the filters itself. [isInitialLoad] exists because
/// the initial (empty) state would otherwise be indistinguishable from a
/// genuinely empty database, and the "No restaurants yet" screen would flash for
/// a frame on every cold start.
@immutable
class RestaurantListUiState {
  const RestaurantListUiState({
    this.filters = const RestaurantFilters(),
    this.availableCuisines = const <String>[],
    this.availableCities = const <String>[],
    this.availableRegions = const <String>[],
    this.availableCountries = const <String>[],
    this.restaurants = const <RestaurantUiModel>[],
    this.favoritesOnly = false,
    this.isInitialLoad = true,
    this.selectedIds = const <String>{},
  });

  final RestaurantFilters filters;
  final List<String> availableCuisines;
  final List<String> availableCities;
  final List<String> availableRegions;
  final List<String> availableCountries;
  final List<RestaurantUiModel> restaurants;

  /// True while the Journal's "Favorites" quick-segment is selected, which
  /// narrows the list to the hearted places after the query rather than in it.
  /// Kept beside [filters] rather than inside it because it never reaches the
  /// database query — it is applied to the rows the query already returned.
  final bool favoritesOnly;

  /// True until the database has emitted for the first time.
  final bool isInitialLoad;

  /// The restaurants ticked in the Journal's selection mode, always a subset of
  /// [restaurants]. Empty whenever the list is not in selection mode.
  final Set<String> selectedIds;

  /// True while at least one restaurant is ticked: the list's contextual
  /// selection mode, entered by a long press and left once nothing is ticked.
  bool get isSelecting => selectedIds.isNotEmpty;

  String get searchQuery => filters.query;
  int? get minRating => filters.minRating;
  String? get cuisineType => filters.cuisineType;
  bool? get visited => filters.visited;

  /// The chosen order. Not a filter: it never narrows the list down, so it is
  /// deliberately absent from [hasActiveFilter] and survives [clearFilters].
  RestaurantSort get sort => filters.sort;

  String? get city => filters.city;
  String? get region => filters.region;
  String? get country => filters.country;
  int? get priceRange => filters.priceRange;

  bool get hasActiveFilter =>
      searchQuery.trim().isNotEmpty ||
      minRating != null ||
      cuisineType != null ||
      visited != null ||
      city != null ||
      region != null ||
      country != null ||
      priceRange != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantListUiState &&
          other.filters == filters &&
          listEquals(other.availableCuisines, availableCuisines) &&
          listEquals(other.availableCities, availableCities) &&
          listEquals(other.availableRegions, availableRegions) &&
          listEquals(other.availableCountries, availableCountries) &&
          listEquals(other.restaurants, restaurants) &&
          other.favoritesOnly == favoritesOnly &&
          other.isInitialLoad == isInitialLoad &&
          setEquals(other.selectedIds, selectedIds);

  @override
  int get hashCode => Object.hash(
    filters,
    Object.hashAll(availableCuisines),
    Object.hashAll(availableCities),
    Object.hashAll(availableRegions),
    Object.hashAll(availableCountries),
    Object.hashAll(restaurants),
    favoritesOnly,
    isInitialLoad,
    Object.hashAllUnordered(selectedIds),
  );

  @override
  String toString() =>
      'RestaurantListUiState(${restaurants.length} restaurants, '
      'initialLoad: $isInitialLoad, $filters)';
}
