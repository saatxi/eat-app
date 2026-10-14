import '../db/app_database.dart';
import '../db/daos/restaurant_dao.dart';
import '../db/daos/visit_dao.dart';
import '../models/stats_projections.dart';

/// The statistics screen's read-only queries, plus the home-screen widget's
/// random pick. Nothing here writes, so it needs no [WriteEffects].
class StatsRepository {
  StatsRepository(this._database);

  final AppDatabase _database;

  late final RestaurantDao _restaurants = _database.restaurantDao;
  late final VisitDao _visits = _database.visitDao;

  Stream<int> observeTotalCount({String? groupId}) =>
      _restaurants.observeTotalCount(groupId: groupId);

  Stream<int> observeVisitedCount({String? groupId}) =>
      _visits.observeVisitedCount(groupId: groupId);

  Stream<double?> observeAverageRating({String? groupId}) =>
      _visits.observeAverageRating(groupId: groupId);

  Stream<List<CuisineCount>> observeCuisineCounts({String? groupId}) =>
      _restaurants.observeCuisineCounts(groupId: groupId);

  Stream<List<PriceRangeCount>> observePriceRangeCounts({String? groupId}) =>
      _restaurants.observePriceRangeCounts(groupId: groupId);

  /// Every visit's raw epoch-millis date, across every restaurant — bucketed
  /// into months by the statistics screen, which is why this is the raw
  /// list.
  Stream<List<int>> observeAllVisitDates({String? groupId}) =>
      _visits.observeAllVisitDates(groupId: groupId);

  /// Every visit's raw date and rating, for the monthly-average chart.
  Stream<List<VisitDateRating>> observeAllVisitDateRatings({
    String? groupId,
  }) => _visits.observeAllVisitDateRatings(groupId: groupId);

  /// One random want-to-try restaurant, for the home-screen widget. A
  /// one-shot query rather than a stream, since the widget asks again each
  /// time it (re)renders instead of observing. Null when nothing is
  /// want-to-try.
  Future<Restaurant?> getRandomWantToTry({String? groupId}) =>
      _restaurants.getRandomWantToTry(groupId: groupId);
}
