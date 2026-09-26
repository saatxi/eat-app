import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../list/restaurant_ui_model.dart';
import 'roulette.dart';

/// Everything the roulette screen draws.
@immutable
class RouletteState {
  const RouletteState({
    this.minRating,
    this.favoritesOnly = false,
    this.visited,
    this.priceRange,
    this.candidates = const <RestaurantUiModel>[],
    this.picked,
    this.pickCount = 0,
    this.isInitialLoad = true,
  });

  final int? minRating;
  final bool favoritesOnly;
  final bool? visited;
  final int? priceRange;

  final List<RestaurantUiModel> candidates;

  /// Null until a spin has produced something, and cleared again the moment the
  /// filters move it out of the pool.
  final RestaurantUiModel? picked;

  /// Bumped on every spin, so the screen can retrigger its shuffle even when
  /// chance lands on the same restaurant twice in a row.
  final int pickCount;

  final bool isInitialLoad;

  bool get isEmpty => !isInitialLoad && candidates.isEmpty;
}

/// Picks at random among the restaurants passing the screen's own light filters,
/// reusing the shared list query rather than adding another one.
///
/// The Flutter counterpart of the Android `RouletteViewModel`. The candidate
/// pool and the pick are both recomputed from one place ([_publish]) rather than
/// from two streams, which is what keeps a filter change from ever leaving a
/// stale pick on screen.
class RouletteController extends ChangeNotifier {
  RouletteController({
    required this.repository,
    required this.preferences,
    Random? random,
  }) : random = random ?? Random() {
    _favoriteIds = preferences.current.favoriteIds;
    preferences.listenable.addListener(_onPreferencesChanged);
    _latestVisitsSubscription =
        repository.observeLatestVisitByRestaurantId().listen(
      (Map<String, Visit> value) {
        _latestVisits = value;
        _publish();
      },
    );
    _photoPathsSubscription = repository.observeRestaurantPhotoPaths().listen(
      (Map<String, String> value) {
        _photoPaths = value;
        _publish();
      },
    );
    _subscribe();
  }

  final RestaurantRepository repository;
  final UserPreferencesRepository preferences;
  final Random random;

  RouletteState _state = const RouletteState();
  RouletteFilters _filters = const RouletteFilters();

  StreamSubscription<List<Restaurant>>? _restaurantsSubscription;
  StreamSubscription<Map<String, Visit>>? _latestVisitsSubscription;
  StreamSubscription<Map<String, String>>? _photoPathsSubscription;

  List<Restaurant> _restaurants = const <Restaurant>[];
  List<Restaurant> _candidates = const <Restaurant>[];
  Restaurant? _picked;
  Map<String, Visit> _latestVisits = const <String, Visit>{};
  Map<String, String> _photoPaths = const <String, String>{};
  Set<String> _favoriteIds = const <String>{};
  int _pickCount = 0;
  bool _loaded = false;
  bool _disposed = false;

  RouletteState get state => _state;

  void onMinRatingChange(int? rating) =>
      _setFilters(_filters.withMinRating(rating));

  void onFavoritesOnlyChange(bool favoritesOnly) =>
      _setFilters(_filters.withFavoritesOnly(favoritesOnly));

  void onVisitedChange(bool? visited) =>
      _setFilters(_filters.withVisited(visited));

  void onPriceRangeChange(int? priceRange) =>
      _setFilters(_filters.withPriceRange(priceRange));

  void pick() {
    _picked = pickRouletteCandidate(_candidates, random);
    _pickCount++;
    _publish();
  }

  @override
  void dispose() {
    _disposed = true;
    preferences.listenable.removeListener(_onPreferencesChanged);
    unawaited(_restaurantsSubscription?.cancel());
    unawaited(_latestVisitsSubscription?.cancel());
    unawaited(_photoPathsSubscription?.cancel());
    super.dispose();
  }

  void _setFilters(RouletteFilters next) {
    _filters = next;
    _subscribe();
    _publish();
  }

  void _subscribe() {
    if (_disposed) {
      return;
    }
    unawaited(_restaurantsSubscription?.cancel());
    _restaurantsSubscription = repository
        .observeFiltered(
          minRating: _filters.minRating,
          visited: _filters.visited,
        )
        .listen((List<Restaurant> value) {
          _restaurants = value;
          _loaded = true;
          _publish();
        });
  }

  void _onPreferencesChanged() {
    _favoriteIds = preferences.current.favoriteIds;
    _publish();
  }

  void _publish() {
    if (_disposed) {
      return;
    }
    _candidates = rouletteCandidates(
      restaurants: _restaurants,
      filters: _filters,
      favoriteIds: _favoriteIds,
    );
    // Dropped the moment it stops matching, so the screen falls back to its
    // "spin" prompt instead of showing a restaurant the filters exclude.
    _picked = retainCandidate(_picked, _candidates);

    final List<RestaurantUiModel> models = <RestaurantUiModel>[
      for (final Restaurant restaurant in _candidates)
        restaurant.toUiModel(
          isFavorite: _favoriteIds.contains(restaurant.id),
          latestVisit: _latestVisits[restaurant.id],
          photoPath: _photoPaths[restaurant.id],
        ),
    ];
    RestaurantUiModel? pickedModel;
    for (final RestaurantUiModel model in models) {
      if (model.id == _picked?.id) {
        pickedModel = model;
        break;
      }
    }

    _state = RouletteState(
      minRating: _filters.minRating,
      favoritesOnly: _filters.favoritesOnly,
      visited: _filters.visited,
      priceRange: _filters.priceRange,
      candidates: models,
      picked: pickedModel,
      pickCount: _pickCount,
      isInitialLoad: !_loaded,
    );
    notifyListeners();
  }
}
