import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/stats_projections.dart';
import '../../data/repositories/restaurant_repository.dart';
import 'monthly_trends.dart';

/// Everything the statistics screen draws, as one snapshot.
@immutable
class StatisticsState {
  const StatisticsState({
    this.isInitialLoad = true,
    this.totalCount = 0,
    this.visitedCount = 0,
    this.wantToTryCount = 0,
    this.averageRating,
    this.cuisineCounts = const <CuisineCount>[],
    this.priceRangeCounts = const <PriceRangeCount>[],
    this.tagCounts = const <TagCount>[],
    this.monthlyVisitCounts = const <MonthlyVisitCount>[],
    this.monthlyRatingTrend = const <MonthlyAverageRating>[],
  });

  final bool isInitialLoad;
  final int totalCount;
  final int visitedCount;

  /// Derived rather than queried: a restaurant with no visit is exactly a
  /// want-to-try one, so the two counts can never disagree.
  final int wantToTryCount;

  final double? averageRating;

  final List<CuisineCount> cuisineCounts;
  final List<PriceRangeCount> priceRangeCounts;
  final List<TagCount> tagCounts;
  final List<MonthlyVisitCount> monthlyVisitCounts;
  final List<MonthlyAverageRating> monthlyRatingTrend;
}

/// Drives the statistics screen: one subscription per aggregate query, folded
/// into a single [StatisticsState].
///
/// The Flutter counterpart of the Android `StatisticsViewModel`. The two
/// time-series are bucketed locally by [monthly_trends] rather than in SQL,
/// because month-of-epoch-millis is not a portable SQLite expression and the
/// data set is a personal notebook's.
class StatisticsController extends ChangeNotifier {
  StatisticsController({
    required this.repository,
    this.clock = DateTime.now,
  }) {
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      repository.observeTotalCount().listen((int value) {
        _totalCount = value;
        _loaded = true;
        _publish();
      }),
      repository.observeVisitedCount().listen((int value) {
        _visitedCount = value;
        _publish();
      }),
      repository.observeAverageRating().listen((double? value) {
        _averageRating = value;
        _publish();
      }),
      repository.observeCuisineCounts().listen((List<CuisineCount> value) {
        _cuisineCounts = value;
        _publish();
      }),
      repository.observePriceRangeCounts().listen((List<PriceRangeCount> value) {
        _priceRangeCounts = value;
        _publish();
      }),
      repository.observeTagCounts().listen((List<TagCount> value) {
        _tagCounts = value;
        _publish();
      }),
      repository.observeAllVisitDates().listen((List<int> value) {
        _visitDates = value;
        _publish();
      }),
      repository.observeAllVisitDateRatings().listen(
        (List<VisitDateRating> value) {
          _visitDateRatings = value;
          _publish();
        },
      ),
    ]);
  }

  final RestaurantRepository repository;

  /// Reads "now" for the trailing-month window; injectable so the window is
  /// testable at all.
  final DateTime Function() clock;

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  StatisticsState _state = const StatisticsState();
  int _totalCount = 0;
  int _visitedCount = 0;
  double? _averageRating;
  List<CuisineCount> _cuisineCounts = const <CuisineCount>[];
  List<PriceRangeCount> _priceRangeCounts = const <PriceRangeCount>[];
  List<TagCount> _tagCounts = const <TagCount>[];
  List<int> _visitDates = const <int>[];
  List<VisitDateRating> _visitDateRatings = const <VisitDateRating>[];
  bool _loaded = false;
  bool _disposed = false;

  StatisticsState get state => _state;

  @override
  void dispose() {
    _disposed = true;
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    super.dispose();
  }

  void _publish() {
    if (_disposed) {
      return;
    }
    final DateTime now = clock();
    _state = StatisticsState(
      isInitialLoad: !_loaded,
      totalCount: _totalCount,
      visitedCount: _visitedCount,
      wantToTryCount: _totalCount - _visitedCount,
      averageRating: _averageRating,
      cuisineCounts: _cuisineCounts,
      priceRangeCounts: _priceRangeCounts,
      tagCounts: _tagCounts,
      monthlyVisitCounts: bucketVisitsByMonth(_visitDates, now: now),
      monthlyRatingTrend: bucketRatingsByMonth(_visitDateRatings, now: now),
    );
    notifyListeners();
  }
}
