import 'package:drift/drift.dart';

import '../../models/stats_projections.dart';
import '../app_database.dart';
import '../tables.dart';

part 'visit_dao.g.dart';

/// Every per-visit query. A restaurant with no visits is a "want to try" entry;
/// one or more makes it "visited".
@DriftAccessor(tables: <Type>[Visits])
class VisitDao extends DatabaseAccessor<AppDatabase> with _$VisitDaoMixin {
  VisitDao(super.db);

  Stream<List<Visit>> observeVisitsForRestaurant(String restaurantId) =>
      customSelect(
        'SELECT * FROM visits WHERE restaurantId = ? ORDER BY visitDate DESC',
        variables: <Variable<Object>>[Variable<String>(restaurantId)],
        readsFrom: <ResultSetImplementation>{visits},
      ).watch().map(_mapVisits);

  /// One-shot: the most recent visit, if any — used to prefill the edit form.
  Future<Visit?> getLatestVisit(String restaurantId) => customSelect(
    'SELECT * FROM visits WHERE restaurantId = ? '
    'ORDER BY visitDate DESC LIMIT 1',
    variables: <Variable<Object>>[Variable<String>(restaurantId)],
    readsFrom: <ResultSetImplementation>{visits},
  ).getSingleOrNull().then(
    (QueryRow? row) => row == null ? null : visits.map(row.data),
  );

  /// Every restaurant's most recent visit in one shot — backs the list,
  /// favorites and roulette rows.
  Stream<List<Visit>> observeLatestVisitByRestaurantId() => customSelect(
    'SELECT v.* FROM visits v '
    'INNER JOIN (SELECT restaurantId, MAX(visitDate) AS maxDate FROM visits '
    'GROUP BY restaurantId) latest '
    'ON latest.restaurantId = v.restaurantId AND latest.maxDate = v.visitDate',
    readsFrom: <ResultSetImplementation>{visits},
  ).watch().map(_mapVisits);

  Future<void> insertVisit(Visit row) => into(visits).insert(row);

  /// `UPDATE`, not drift's `replace` — see `RestaurantDao.updateRestaurant`.
  Future<void> updateVisit(Visit row) =>
      (update(visits)..where((t) => t.id.equals(row.id))).write(row);

  Future<void> deleteVisit(String id) =>
      (delete(visits)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAllVisitsForRestaurant(String restaurantId) =>
      (delete(visits)..where((t) => t.restaurantId.equals(restaurantId))).go();

  /// One-shot snapshot of every visit, used to write the full backup file.
  Future<List<Visit>> getAllVisits() => customSelect(
    'SELECT * FROM visits',
    readsFrom: <ResultSetImplementation>{visits},
  ).get().then(_mapVisits);

  Stream<int> observeVisitedCount() => customSelect(
    'SELECT COUNT(DISTINCT restaurantId) AS count FROM visits',
    readsFrom: <ResultSetImplementation>{visits},
  ).watchSingle().map((QueryRow row) => row.read<int>('count'));

  /// Null when nothing has a real visit yet.
  Stream<double?> observeAverageRating() => customSelect(
    'SELECT AVG(rating) AS average FROM visits',
    readsFrom: <ResultSetImplementation>{visits},
  ).watchSingle().map((QueryRow row) => row.read<double?>('average'));

  /// Every visit's raw epoch-millis date, across every restaurant — bucketed
  /// into months by the caller rather than in SQL, since month-of-epoch-millis
  /// isn't a portable single expression and this table is small enough that
  /// bucketing in Dart is simpler.
  Stream<List<int>> observeAllVisitDates() => customSelect(
    'SELECT visitDate AS visitDate FROM visits ORDER BY visitDate ASC',
    readsFrom: <ResultSetImplementation>{visits},
  ).watch().map(
    (List<QueryRow> rows) => <int>[
      for (final QueryRow row in rows) row.read<int>('visitDate'),
    ],
  );

  /// Every visit's raw date and rating — bucketed into a monthly average by the
  /// caller, same rationale as [observeAllVisitDates].
  Stream<List<VisitDateRating>> observeAllVisitDateRatings() => customSelect(
    'SELECT visitDate AS visitDate, rating AS rating FROM visits '
    'ORDER BY visitDate ASC',
    readsFrom: <ResultSetImplementation>{visits},
  ).watch().map(
    (List<QueryRow> rows) => <VisitDateRating>[
      for (final QueryRow row in rows)
        VisitDateRating(
          visitDate: row.read<int>('visitDate'),
          rating: row.read<int>('rating'),
        ),
    ],
  );

  List<Visit> _mapVisits(List<QueryRow> rows) => <Visit>[
    for (final QueryRow row in rows) visits.map(row.data),
  ];
}
