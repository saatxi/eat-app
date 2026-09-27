import 'package:drift/drift.dart';

import '../../models/stats_projections.dart';
import '../app_database.dart';
import '../tables.dart';

part 'visit_dao.g.dart';

/// Every per-visit query. A restaurant with no visits is a "want to try" entry;
/// one or more makes it "visited".
///
/// Soft-deleted rows are excluded throughout: a visit tombstoned by a shared
/// delete (locally or by another member) must not count as a visit, feed a
/// rating trend, or keep a restaurant looking "visited".
@DriftAccessor(tables: <Type>[Visits])
class VisitDao extends DatabaseAccessor<AppDatabase> with _$VisitDaoMixin {
  VisitDao(super.db);

  Stream<List<Visit>> observeVisitsForRestaurant(String restaurantId) =>
      customSelect(
        'SELECT * FROM visits WHERE restaurantId = ? AND deletedAt IS NULL '
        'ORDER BY visitDate DESC',
        variables: <Variable<Object>>[Variable<String>(restaurantId)],
        readsFrom: <ResultSetImplementation>{visits},
      ).watch().map(_mapVisits);

  /// One-shot: the most recent visit, if any — used to prefill the edit form.
  Future<Visit?> getLatestVisit(String restaurantId) => customSelect(
    'SELECT * FROM visits WHERE restaurantId = ? AND deletedAt IS NULL '
    'ORDER BY visitDate DESC LIMIT 1',
    variables: <Variable<Object>>[Variable<String>(restaurantId)],
    readsFrom: <ResultSetImplementation>{visits},
  ).getSingleOrNull().then(
    (QueryRow? row) => row == null ? null : visits.map(row.data),
  );

  /// Every restaurant's most recent visit in one shot — backs the list,
  /// favorites and roulette rows.
  /// [groupId] scopes the rows the same way `RestaurantDao`'s collection
  /// queries do: a group id shows that group's visits, null the private ones.
  Stream<List<Visit>> observeLatestVisitByRestaurantId({String? groupId}) =>
      customSelect(
        'SELECT v.* FROM visits v '
        'INNER JOIN (SELECT restaurantId, MAX(visitDate) AS maxDate FROM visits '
        'WHERE deletedAt IS NULL GROUP BY restaurantId) latest '
        'ON latest.restaurantId = v.restaurantId AND latest.maxDate = v.visitDate '
        'WHERE v.deletedAt IS NULL AND v.groupId IS ?',
        variables: <Variable<Object>>[Variable<String>(groupId)],
        readsFrom: <ResultSetImplementation>{visits},
      ).watch().map(_mapVisits);

  Future<void> insertVisit(Visit row) => into(visits).insert(row);

  /// `UPDATE`, not drift's `replace` — see `RestaurantDao.updateRestaurant`.
  Future<void> updateVisit(Visit row) =>
      (update(visits)..where((t) => t.id.equals(row.id))).write(row);

  /// Writes a visit back in place, clearing any tombstone. Used when the edit
  /// form rewrites the single visit of a shared restaurant: the row is revived
  /// rather than re-inserted, so its id stays stable. `toCompanion(false)`
  /// includes the null columns, which is what actually clears `deletedAt`.
  Future<void> reviveVisit(Visit row) =>
      into(visits).insertOnConflictUpdate(row.toCompanion(false));

  Future<void> deleteVisit(String id) =>
      (delete(visits)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAllVisitsForRestaurant(String restaurantId) =>
      (delete(visits)..where((t) => t.restaurantId.equals(restaurantId))).go();

  /// One-shot lookup by id, tombstones *included* — see `RestaurantDao.getById`.
  Future<Visit?> getById(String id) => customSelect(
    'SELECT * FROM visits WHERE id = ?',
    variables: <Variable<Object>>[Variable<String>(id)],
    readsFrom: <ResultSetImplementation>{visits},
  ).getSingleOrNull().then(
    (QueryRow? row) => row == null ? null : visits.map(row.data),
  );

  /// Every visit of a restaurant, tombstones *included* — the rows to tombstone
  /// when a shared restaurant is soft-deleted.
  Future<List<Visit>> getVisitsForRestaurant(String restaurantId) =>
      customSelect(
        'SELECT * FROM visits WHERE restaurantId = ?',
        variables: <Variable<Object>>[Variable<String>(restaurantId)],
        readsFrom: <ResultSetImplementation>{visits},
      ).get().then(_mapVisits);

  /// Tombstones one shared visit — see `RestaurantDao.softDeleteRestaurant`.
  Future<void> softDeleteVisit(String id, int timestamp) =>
      (update(visits)..where((t) => t.id.equals(id))).write(
        VisitsCompanion(
          deletedAt: Value<int>(timestamp),
          updatedAt: Value<int>(timestamp),
        ),
      );

  /// Tombstones every visit of a restaurant, for the shared-restaurant delete.
  Future<void> softDeleteVisitsForRestaurant(
    String restaurantId,
    int timestamp,
  ) => (update(visits)..where((t) => t.restaurantId.equals(restaurantId))).write(
    VisitsCompanion(
      deletedAt: Value<int>(timestamp),
      updatedAt: Value<int>(timestamp),
    ),
  );

  /// One-shot snapshot of every visit, used to write the full backup file.
  Future<List<Visit>> getAllVisits() => customSelect(
    'SELECT * FROM visits WHERE deletedAt IS NULL',
    readsFrom: <ResultSetImplementation>{visits},
  ).get().then(_mapVisits);

  Stream<int> observeVisitedCount({String? groupId}) => customSelect(
    'SELECT COUNT(DISTINCT restaurantId) AS count FROM visits '
    'WHERE deletedAt IS NULL AND groupId IS ?',
    variables: <Variable<Object>>[Variable<String>(groupId)],
    readsFrom: <ResultSetImplementation>{visits},
  ).watchSingle().map((QueryRow row) => row.read<int>('count'));

  /// Null when nothing has a real visit yet.
  Stream<double?> observeAverageRating({String? groupId}) => customSelect(
    'SELECT AVG(rating) AS average FROM visits '
    'WHERE deletedAt IS NULL AND groupId IS ?',
    variables: <Variable<Object>>[Variable<String>(groupId)],
    readsFrom: <ResultSetImplementation>{visits},
  ).watchSingle().map((QueryRow row) => row.read<double?>('average'));

  /// Every visit's raw epoch-millis date, across every restaurant — bucketed
  /// into months by the caller rather than in SQL, since month-of-epoch-millis
  /// isn't a portable single expression and this table is small enough that
  /// bucketing in Dart is simpler.
  Stream<List<int>> observeAllVisitDates({String? groupId}) => customSelect(
    'SELECT visitDate AS visitDate FROM visits '
    'WHERE deletedAt IS NULL AND groupId IS ? ORDER BY visitDate ASC',
    variables: <Variable<Object>>[Variable<String>(groupId)],
    readsFrom: <ResultSetImplementation>{visits},
  ).watch().map(
    (List<QueryRow> rows) => <int>[
      for (final QueryRow row in rows) row.read<int>('visitDate'),
    ],
  );

  /// Every visit's raw date and rating — bucketed into a monthly average by the
  /// caller, same rationale as [observeAllVisitDates].
  Stream<List<VisitDateRating>> observeAllVisitDateRatings({String? groupId}) =>
      customSelect(
        'SELECT visitDate AS visitDate, rating AS rating FROM visits '
        'WHERE deletedAt IS NULL AND groupId IS ? ORDER BY visitDate ASC',
        variables: <Variable<Object>>[Variable<String>(groupId)],
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
