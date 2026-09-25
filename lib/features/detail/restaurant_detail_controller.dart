import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../list/restaurant_ui_model.dart';
import 'detail_state.dart';

/// Drives the detail screen: one subscription per source of data, folded into a
/// single [DetailState] whenever any of them moves.
///
/// The Flutter counterpart of the Android `RestaurantDetailViewModel`. The one
/// place it departs from a straight port is the visit photos: Kotlin used
/// `flatMapLatest` over a `combine` of one flow per visit, but Dart has no
/// equivalent, so the controller keeps a subscription per visit and reconciles
/// them when the visit list changes — the same observable behaviour, expressed
/// with the primitives Dart actually has.
///
/// Unlike the list controller, the collaborators are positional-and-hidden here
/// because the constructor also takes the id and nothing about it is a
/// configuration knob a call site reads; the repository and preferences are
/// still public for the same reason as the list's.
class RestaurantDetailController extends ChangeNotifier {
  RestaurantDetailController({
    required this.repository,
    required this.preferences,
    required this.restaurantId,
  }) {
    _favoriteIds = preferences.current.favoriteIds;
    preferences.listenable.addListener(_onPreferencesChanged);

    _subscriptions.addAll(<StreamSubscription<Object?>>[
      repository.observeById(restaurantId).listen((Restaurant? value) {
        _restaurant = value;
        _restaurantEmitted = true;
        _publish();
      }),
      repository.observeTagNames(restaurantId).listen((List<String> value) {
        _tags = value;
        _publish();
      }),
      repository.observeVisitsForRestaurant(restaurantId).listen(_onVisits),
    ]);
  }

  final RestaurantRepository repository;
  final UserPreferencesRepository preferences;
  final String restaurantId;

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  /// One per visit currently in the list; kept in step by [_onVisits].
  final Map<String, StreamSubscription<Object>> _photoSubscriptions =
      <String, StreamSubscription<Object>>{};

  DetailState _state = const DetailLoading();
  Restaurant? _restaurant;
  List<Visit> _visits = const <Visit>[];
  List<String> _tags = const <String>[];
  Set<String> _favoriteIds = const <String>{};
  final Map<String, List<String>> _photosByVisitId = <String, List<String>>{};

  /// Flipped by the first emission of the restaurant query — an absent row
  /// before that means "still loading", not "deleted".
  bool _restaurantEmitted = false;
  bool _disposed = false;

  DetailState get state => _state;

  Future<void> toggleFavorite() => preferences.toggleFavorite(restaurantId);

  /// The caller pops the screen once this completes.
  Future<void> deleteRestaurant() => repository.delete(restaurantId);

  @override
  void dispose() {
    _disposed = true;
    preferences.listenable.removeListener(_onPreferencesChanged);
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    for (final StreamSubscription<Object> subscription
        in _photoSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _photoSubscriptions.clear();
    super.dispose();
  }

  void _onVisits(List<Visit> visits) {
    _visits = visits;
    _reconcilePhotoSubscriptions(visits);
    _publish();
  }

  /// Starts a photo subscription for each visit that has none, and drops the
  /// ones whose visit has gone (a delete, or a whole-history rewrite).
  void _reconcilePhotoSubscriptions(List<Visit> visits) {
    final Set<String> ids = <String>{for (final Visit visit in visits) visit.id};
    for (final String id in _photoSubscriptions.keys.toList()) {
      if (!ids.contains(id)) {
        unawaited(_photoSubscriptions.remove(id)!.cancel());
        _photosByVisitId.remove(id);
      }
    }
    for (final String id in ids) {
      _photoSubscriptions.putIfAbsent(
        id,
        () => repository.observePhotosForVisit(id).listen((List<Photo> photos) {
          _photosByVisitId[id] = <String>[for (final Photo photo in photos) photo.path];
          _publish();
        }),
      );
    }
  }

  void _onPreferencesChanged() {
    _favoriteIds = preferences.current.favoriteIds;
    _publish();
  }

  void _publish() {
    if (_disposed) {
      return;
    }
    if (!_restaurantEmitted) {
      _setState(const DetailLoading());
      return;
    }
    final Restaurant? restaurant = _restaurant;
    if (restaurant == null) {
      _setState(const DetailNotFound());
      return;
    }

    final List<Visit> visits = _visits;
    _setState(
      DetailLoaded(
        restaurant: restaurant.toUiModel(
          isFavorite: _favoriteIds.contains(restaurant.id),
          tags: _tags,
          latestVisit: visits.isEmpty ? null : visits.first,
        ),
        visits: <VisitUiModel>[
          for (final Visit visit in visits)
            VisitUiModel(
              id: visit.id,
              visitDate: visit.visitDate,
              rating: visit.rating,
              notes: _nonBlank(visit.notes),
              priceRange: visit.priceRange,
              photoPaths: _photosByVisitId[visit.id] ?? const <String>[],
            ),
        ],
        // `visits` arrives newest-first; a trend line reads left-to-right
        // chronologically.
        ratingTrend: visits.length >= minVisitsForTrend
            ? <RatingPoint>[
                for (final Visit visit in (List<Visit>.of(visits)
                  ..sort((Visit a, Visit b) => a.visitDate.compareTo(b.visitDate))))
                  RatingPoint(visitDate: visit.visitDate, rating: visit.rating),
              ]
            : const <RatingPoint>[],
      ),
    );
  }

  void _setState(DetailState next) {
    if (next == _state) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  static String? _nonBlank(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}
