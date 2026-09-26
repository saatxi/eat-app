import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../../data/models/restaurant_sort.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
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
    this.isInitialLoad = true,
  });

  final RestaurantFilters filters;
  final List<String> availableCuisines;
  final List<String> availableCities;
  final List<String> availableRegions;
  final List<String> availableCountries;
  final List<RestaurantUiModel> restaurants;

  /// True until the database has emitted for the first time.
  final bool isInitialLoad;

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
          other.isInitialLoad == isInitialLoad;

  @override
  int get hashCode => Object.hash(
    filters,
    Object.hashAll(availableCuisines),
    Object.hashAll(availableCities),
    Object.hashAll(availableRegions),
    Object.hashAll(availableCountries),
    Object.hashAll(restaurants),
    isInitialLoad,
  );

  @override
  String toString() =>
      'RestaurantListUiState(${restaurants.length} restaurants, '
      'initialLoad: $isInitialLoad, $filters)';
}

/// Drives the list screen: it owns the filters, keeps one subscription per
/// source of data, and republishes a [RestaurantListUiState] whenever any of
/// them changes.
///
/// It is the Flutter counterpart of the Android `RestaurantListViewModel`, and
/// the one place where that screen's `combine`/`flatMapLatest` plumbing gets
/// rewritten: Dart streams have no `combineLatest`, so rather than nesting
/// adapters the controller holds the last value of each source and recomputes
/// the snapshot when one of them moves. The observable behaviour is the same —
/// a subscription per stream, one rebuild per change.
///
/// Two details are load-bearing and carried over from the Android version:
///
/// * Only the query is debounced ([searchDebounce]), and a blank one skips the
///   debounce entirely so clearing the field brings the results back at once.
///   Every other filter, and the order, take effect immediately.
/// * The filters on screen and the filters the query was built from are not the
///   same thing: the state always shows what was just typed, while the restaurant
///   subscription lags behind by the debounce.
class RestaurantListController extends ChangeNotifier {
  RestaurantListController({
    required this.repository,
    required this.preferences,
    this.searchDebounce = const Duration(milliseconds: 250),
    this.favouritesOnly = false,
  }) {
    _favoriteIds = preferences.current.favoriteIds;
    preferences.listenable.addListener(_onPreferencesChanged);

    _dataSubscriptions.addAll(<StreamSubscription<Object>>[
      repository.observeTagsByRestaurantId().listen(
        (Map<String, List<String>> value) {
          _tagsByRestaurantId = value;
          _publish();
        },
      ),
      repository.observeLatestVisitByRestaurantId().listen(
        (Map<String, Visit> value) {
          _latestVisitByRestaurantId = value;
          _publish();
        },
      ),
      repository.observeRestaurantPhotoPaths().listen(
        (Map<String, String> value) {
          _photoPathsByRestaurantId = value;
          _publish();
        },
      ),
      repository.observeCuisineTypes().listen((List<String> value) {
        _availableCuisines = value;
        _publish();
      }),
      repository.observeCities().listen((List<String> value) {
        _availableCities = value;
        _publish();
      }),
      repository.observeRegions().listen((List<String> value) {
        _availableRegions = value;
        _publish();
      }),
      repository.observeCountries().listen((List<String> value) {
        _availableCountries = value;
        _publish();
      }),
    ]);

    _subscribeToRestaurants();
  }

  /// Where the restaurants, their tags and their visits are read from.
  ///
  /// The three collaborators are public fields because Dart has no way to
  /// initialise a private field from a named parameter, and a positional
  /// constructor would hide what the call site is passing.
  final RestaurantRepository repository;

  /// The only preference this screen touches: which restaurants are favourites.
  final UserPreferencesRepository preferences;

  /// How long a typed query waits before it reaches the database.
  final Duration searchDebounce;

  /// Narrows the published list to favourites, after the query rather than in
  /// it: the favourites screen is the same list — same search, sort and filters
  /// — just cut down to the ids the preferences hold, exactly as the Android
  /// app's `FavoritesViewModel` does.
  final bool favouritesOnly;

  final List<StreamSubscription<Object>> _dataSubscriptions =
      <StreamSubscription<Object>>[];

  RestaurantListUiState _state = const RestaurantListUiState();
  RestaurantFilters _filters = const RestaurantFilters();

  /// The restaurant query, re-created whenever the filters it was built from
  /// change. Kept apart from [_dataSubscriptions], which live as long as the
  /// controller does.
  StreamSubscription<List<Restaurant>>? _restaurantsSubscription;
  Timer? _debounce;

  List<Restaurant> _restaurants = const <Restaurant>[];
  Map<String, List<String>> _tagsByRestaurantId = const <String, List<String>>{};
  Map<String, Visit> _latestVisitByRestaurantId = const <String, Visit>{};
  Map<String, String> _photoPathsByRestaurantId = const <String, String>{};
  Set<String> _favoriteIds = const <String>{};
  List<String> _availableCuisines = const <String>[];
  List<String> _availableCities = const <String>[];
  List<String> _availableRegions = const <String>[];
  List<String> _availableCountries = const <String>[];

  /// Flipped by the first emission of the restaurant query — reaching a source's
  /// listener at all is the proof that the database has answered.
  bool _loaded = false;
  bool _disposed = false;

  RestaurantListUiState get state => _state;

  void onSearchQueryChange(String query) =>
      _setFilters(_filters.withQuery(query), debounceQuery: true);

  void onMinRatingChange(int? minRating) =>
      _setFilters(_filters.withMinRating(minRating), debounceQuery: false);

  void onCuisineChange(String? cuisineType) =>
      _setFilters(_filters.withCuisineType(cuisineType), debounceQuery: false);

  void onVisitedChange(bool? visited) =>
      _setFilters(_filters.withVisited(visited), debounceQuery: false);

  void onSortChange(RestaurantSort sort) =>
      _setFilters(_filters.withSort(sort), debounceQuery: false);

  void onCityChange(String? city) =>
      _setFilters(_filters.withCity(city), debounceQuery: false);

  void onRegionChange(String? region) =>
      _setFilters(_filters.withRegion(region), debounceQuery: false);

  void onCountryChange(String? country) =>
      _setFilters(_filters.withCountry(country), debounceQuery: false);

  void onPriceRangeChange(int? priceRange) =>
      _setFilters(_filters.withPriceRange(priceRange), debounceQuery: false);

  Future<void> toggleFavorite(String restaurantId) =>
      preferences.toggleFavorite(restaurantId);

  /// The caller has already shown a confirmation dialog before calling this.
  Future<void> deleteRestaurant(String restaurantId) =>
      repository.delete(restaurantId);

  /// Re-runs the list query against the database and waits for its answer.
  ///
  /// The list is already live — every stream it reads republishes on write — so
  /// this is not how it keeps up. It exists for the pull-to-refresh gesture: it
  /// gives the pull something real to wait for rather than a cosmetic pause, and
  /// a way to force a re-read if a stream ever goes quiet.
  Future<void> refresh() async {
    final Completer<void> answered = Completer<void>();
    _subscribeToRestaurants(
      onFirstEmission: () {
        if (!answered.isCompleted) {
          answered.complete();
        }
      },
    );
    await answered.future;
  }

  /// Deliberately leaves [RestaurantSort] alone — see [RestaurantFilters.withoutFilters].
  ///
  /// Reached from the "no matches" state, so it drops the search query too.
  void clearFilters() =>
      _setFilters(_filters.withoutFilters(), debounceQuery: false);

  /// The filter panel's "clear" action: every dimension back to "any" in one
  /// step, with the typed search left where it is — see
  /// [RestaurantFilters.withoutFilterDimensions].
  void clearFilterDimensions() =>
      _setFilters(_filters.withoutFilterDimensions(), debounceQuery: false);

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    preferences.listenable.removeListener(_onPreferencesChanged);
    _cancelRestaurantsSubscription();
    for (final StreamSubscription<Object> subscription in _dataSubscriptions) {
      unawaited(subscription.cancel());
    }
    _dataSubscriptions.clear();
    super.dispose();
  }

  void _setFilters(RestaurantFilters next, {required bool debounceQuery}) {
    // Cheaper than it looks, and it matters: a repeated tap on an already
    // selected chip would otherwise tear the restaurant query down and build it
    // again, for a result set that cannot have changed.
    if (next == _filters) {
      return;
    }
    _filters = next;

    _debounce?.cancel();
    _debounce = null;
    if (!debounceQuery || next.query.trim().isEmpty) {
      _subscribeToRestaurants();
    } else {
      _debounce = Timer(searchDebounce, _subscribeToRestaurants);
    }

    // Published straight away even when the restaurant query is still waiting on
    // its debounce: the field the user is typing into has to show the character
    // they just typed.
    _publish();
  }

  void _subscribeToRestaurants({VoidCallback? onFirstEmission}) {
    if (_disposed) {
      return;
    }
    _cancelRestaurantsSubscription();
    _restaurantsSubscription = repository
        .observeFiltered(
          query: _filters.query,
          minRating: _filters.minRating,
          cuisineType: _filters.cuisineType,
          sort: _filters.sort,
          visited: _filters.visited,
          city: _filters.city,
          region: _filters.region,
          country: _filters.country,
          priceRange: _filters.priceRange,
        )
        .listen((List<Restaurant> value) {
          _restaurants = value;
          _loaded = true;
          _publish();
          onFirstEmission?.call();
        });
  }

  void _cancelRestaurantsSubscription() {
    final StreamSubscription<List<Restaurant>>? subscription =
        _restaurantsSubscription;
    _restaurantsSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  void _onPreferencesChanged() {
    _favoriteIds = preferences.current.favoriteIds;
    _publish();
  }

  /// Rebuilds the snapshot and notifies, unless nothing actually moved: the
  /// tags, visits and vocabulary streams all fire on writes that leave the list
  /// exactly as it was, and repainting every row for those is pure cost.
  void _publish() {
    if (_disposed) {
      return;
    }
    final RestaurantListUiState next = RestaurantListUiState(
      filters: _filters,
      availableCuisines: _availableCuisines,
      availableCities: _availableCities,
      availableRegions: _availableRegions,
      availableCountries: _availableCountries,
      restaurants: <RestaurantUiModel>[
        for (final Restaurant restaurant in _restaurants)
          if (!favouritesOnly || _favoriteIds.contains(restaurant.id))
            restaurant.toUiModel(
              isFavorite: _favoriteIds.contains(restaurant.id),
              tags: _tagsByRestaurantId[restaurant.id] ?? const <String>[],
              latestVisit: _latestVisitByRestaurantId[restaurant.id],
              photoPath: _photoPathsByRestaurantId[restaurant.id],
            ),
      ],
      isInitialLoad: !_loaded,
    );
    if (next == _state) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}
