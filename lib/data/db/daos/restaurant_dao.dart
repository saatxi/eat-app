import 'package:drift/drift.dart';

import '../../models/stats_projections.dart';
import '../app_database.dart';
import '../tables.dart';

part 'restaurant_dao.g.dart';

/// Every restaurant-level query.
///
/// The custom SQL mirrors the Android app's Room queries statement for
/// statement; drift's `customSelect` binds `variables` to the `?` placeholders
/// in the order they appear, so each query's placeholders are listed in its own
/// documentation.
@DriftAccessor(tables: <Type>[Restaurants, Visits, RestaurantGroups])
class RestaurantDao extends DatabaseAccessor<AppDatabase>
    with _$RestaurantDaoMixin {
  RestaurantDao(super.db);

  /// The scope predicate shared by every collection query: a group id shows the
  /// restaurants with a live membership in it, null the ones with no membership
  /// at all (personal). Written against the `restaurants` alias so callers can
  /// interpolate it. Three placeholders: the group id, three times.
  static const String _groupScope =
      '((? IS NULL AND NOT EXISTS (SELECT 1 FROM restaurant_groups rg '
      'WHERE rg.restaurantId = %ALIAS%.id AND rg.deletedAt IS NULL)) '
      'OR (? IS NOT NULL AND EXISTS (SELECT 1 FROM restaurant_groups rg '
      'WHERE rg.restaurantId = %ALIAS%.id AND rg.groupId = ? '
      'AND rg.deletedAt IS NULL)))';

  static List<Variable<Object>> _groupVars(String? groupId) =>
      <Variable<Object>>[
        Variable<String>(groupId),
        Variable<String>(groupId),
        Variable<String>(groupId),
      ];

  /// The list screen's single query.
  ///
  /// Soft-deleted rows are excluded everywhere here: a tombstone pushed by
  /// another member (or written locally as part of a shared delete) is not a
  /// row the UI should show, and neither is a visit of one.
  ///
  /// [groupId] selects the scope: a group id shows that group's rows, null the
  /// private ones only. SQLite's `IS ?` covers both cases in one clause. The
  /// by-parent-id lookups further down deliberately take no such argument —
  /// their scope is whatever the parent row already is.
  ///
  /// Placeholders, in order: the search query (twice — the null check and the
  /// `LIKE`), the minimum rating (twice), the cuisine key (twice), the visited
  /// flag (three times — the null check and its two branches), city, region and
  /// country (twice each), the price range (twice), and finally the
  /// `sortByRating` flag.
  ///
  /// [query] must already be folded with `normalizeForSearch` and escaped with
  /// `escapeLikeWildcards`, since it is matched as a literal substring of the
  /// equally folded `searchText` column — the `ESCAPE '\'` clause is what makes
  /// `%` and `_` in the escaped query match themselves rather than act as
  /// `LIKE` wildcards.
  ///
  /// Ordering is fixed by [sortByRating] rather than interpolated into the SQL:
  /// true puts the highest ratings first (name breaking ties), false leaves the
  /// CASE constant so the name order alone applies. "Rating" and "visited"
  /// resolve through the `visits` table rather than a restaurant-level column.
  Stream<List<Restaurant>> observeFiltered({
    String? query,
    int? minRating,
    String? cuisineType,
    required bool sortByRating,
    bool? visited,
    String? city,
    String? region,
    String? country,
    int? priceRange,
    String? groupId,
  }) {
    final int? visitedFlag = visited == null ? null : (visited ? 1 : 0);

    return customSelect(
      'SELECT * FROM restaurants r '
      'WHERE r.deletedAt IS NULL '
      "AND (? IS NULL OR searchText LIKE '%' || ? || '%' ESCAPE '\\') "
      'AND (? IS NULL OR EXISTS (SELECT 1 FROM visits v '
      'WHERE v.restaurantId = r.id AND v.rating >= ? AND v.deletedAt IS NULL)) '
      'AND (? IS NULL OR cuisineType = ?) '
      'AND (? IS NULL '
      'OR (? = 1 AND EXISTS (SELECT 1 FROM visits v WHERE v.restaurantId = r.id AND v.deletedAt IS NULL)) '
      'OR (? = 0 AND NOT EXISTS (SELECT 1 FROM visits v WHERE v.restaurantId = r.id AND v.deletedAt IS NULL))) '
      'AND (? IS NULL OR city = ?) '
      'AND (? IS NULL OR region = ?) '
      'AND (? IS NULL OR country = ?) '
      'AND (? IS NULL OR priceRange = ?) '
      'AND ${_groupScope.replaceAll('%ALIAS%', 'r')} '
      'ORDER BY CASE WHEN ? THEN '
      '(SELECT MAX(v2.rating) FROM visits v2 WHERE v2.restaurantId = r.id AND v2.deletedAt IS NULL) '
      'ELSE 0 END DESC, name COLLATE NOCASE ASC',
      variables: <Variable<Object>>[
        Variable<String>(query),
        Variable<String>(query),
        Variable<int>(minRating),
        Variable<int>(minRating),
        Variable<String>(cuisineType),
        Variable<String>(cuisineType),
        Variable<int>(visitedFlag),
        Variable<int>(visitedFlag),
        Variable<int>(visitedFlag),
        Variable<String>(city),
        Variable<String>(city),
        Variable<String>(region),
        Variable<String>(region),
        Variable<String>(country),
        Variable<String>(country),
        Variable<int>(priceRange),
        Variable<int>(priceRange),
        ..._groupVars(groupId),
        Variable<bool>(sortByRating),
      ],
      readsFrom: <ResultSetImplementation>{restaurants, visits, restaurantGroups},
    ).watch().map(_mapRestaurants);
  }

  /// The cuisine keys actually present in the data, so the filter row can offer
  /// only those instead of all 24 entries of the vocabulary.
  Stream<List<String>> observeCuisineTypes({String? groupId}) => customSelect(
    'SELECT DISTINCT cuisineType AS cuisineType FROM restaurants '
    'WHERE deletedAt IS NULL '
    'AND ${_groupScope.replaceAll('%ALIAS%', 'restaurants')}',
    variables: _groupVars(groupId),
    readsFrom: <ResultSetImplementation>{restaurants, restaurantGroups},
  ).watch().map(
    (List<QueryRow> rows) => <String>[
      for (final QueryRow row in rows) row.read<String>('cuisineType'),
    ],
  );

  /// Distinct, non-null city values actually present, for the location filter
  /// panel.
  Stream<List<String>> observeCities({String? groupId}) =>
      _observeDistinct('city', groupId: groupId);

  /// Distinct, non-null region values actually present, for the location filter
  /// panel.
  Stream<List<String>> observeRegions({String? groupId}) =>
      _observeDistinct('region', groupId: groupId);

  /// Distinct, non-null country values actually present, for the location
  /// filter panel.
  Stream<List<String>> observeCountries({String? groupId}) =>
      _observeDistinct('country', groupId: groupId);

  Stream<Restaurant?> observeById(String id) => customSelect(
    'SELECT * FROM restaurants WHERE id = ? AND deletedAt IS NULL',
    variables: <Variable<Object>>[Variable<String>(id)],
    readsFrom: <ResultSetImplementation>{restaurants},
  ).watchSingleOrNull().map(
    (QueryRow? row) => row == null ? null : restaurants.map(row.data),
  );

  /// A one-shot snapshot of every row, used to write the full backup file after
  /// each write.
  Future<List<Restaurant>> getAll() => customSelect(
    'SELECT * FROM restaurants WHERE deletedAt IS NULL '
    'ORDER BY name COLLATE NOCASE ASC',
    readsFrom: <ResultSetImplementation>{restaurants},
  ).get().then(_mapRestaurants);

  Future<void> insertRestaurant(Restaurant row) => into(restaurants).insert(row);

  /// Deliberately `UPDATE` rather than drift's `replace` (an `INSERT OR
  /// REPLACE`): replacing the row would delete and re-insert it, and with
  /// foreign keys on that cascades into wiping the restaurant's visits and
  /// photos.
  Future<void> updateRestaurant(Restaurant row) =>
      (update(restaurants)..where((t) => t.id.equals(row.id))).write(row);

  Future<void> deleteRestaurant(String id) =>
      (delete(restaurants)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAllRestaurants() => delete(restaurants).go();

  /// One-shot lookup by id, tombstones *included*: the repository needs a row's
  /// own `groupId` to decide whether a delete is the shared soft kind, and this
  /// is the one place that must see a row regardless of its tombstone state.
  Future<Restaurant?> getById(String id) => customSelect(
    'SELECT * FROM restaurants WHERE id = ?',
    variables: <Variable<Object>>[Variable<String>(id)],
    readsFrom: <ResultSetImplementation>{restaurants},
  ).getSingleOrNull().then(
    (QueryRow? row) => row == null ? null : restaurants.map(row.data),
  );

  /// Marks a shared row deleted without removing it, so a pull can deliver the
  /// deletion to every member. [timestamp] is both the tombstone and the
  /// last-write stamp the sync layer compares on.
  Future<void> softDeleteRestaurant(String id, int timestamp) =>
      (update(restaurants)..where((t) => t.id.equals(id))).write(
        RestaurantsCompanion(
          deletedAt: Value<int>(timestamp),
          updatedAt: Value<int>(timestamp),
        ),
      );

  // --- Statistics -----------------------------------------------------------

  Stream<int> observeTotalCount({String? groupId}) => customSelect(
    'SELECT COUNT(*) AS count FROM restaurants '
    'WHERE deletedAt IS NULL '
    'AND ${_groupScope.replaceAll('%ALIAS%', 'restaurants')}',
    variables: _groupVars(groupId),
    readsFrom: <ResultSetImplementation>{restaurants, restaurantGroups},
  ).watchSingle().map((QueryRow row) => row.read<int>('count'));

  Stream<List<CuisineCount>> observeCuisineCounts({String? groupId}) =>
      customSelect(
        'SELECT cuisineType AS cuisineType, COUNT(*) AS count FROM restaurants '
        'WHERE deletedAt IS NULL '
        'AND ${_groupScope.replaceAll('%ALIAS%', 'restaurants')} '
        'GROUP BY cuisineType ORDER BY count DESC',
        variables: _groupVars(groupId),
        readsFrom: <ResultSetImplementation>{restaurants, restaurantGroups},
  ).watch().map(
    (List<QueryRow> rows) => <CuisineCount>[
      for (final QueryRow row in rows)
        CuisineCount(
          cuisineType: row.read<String>('cuisineType'),
          count: row.read<int>('count'),
        ),
    ],
  );

  Stream<List<PriceRangeCount>> observePriceRangeCounts({String? groupId}) =>
      customSelect(
        'SELECT priceRange AS priceRange, COUNT(*) AS count FROM restaurants '
        'WHERE deletedAt IS NULL '
        'AND ${_groupScope.replaceAll('%ALIAS%', 'restaurants')} '
        'GROUP BY priceRange',
        variables: _groupVars(groupId),
        readsFrom: <ResultSetImplementation>{restaurants, restaurantGroups},
  ).watch().map(
    (List<QueryRow> rows) => <PriceRangeCount>[
      for (final QueryRow row in rows)
        PriceRangeCount(
          priceRange: row.read<int>('priceRange'),
          count: row.read<int>('count'),
        ),
    ],
  );

  /// One random want-to-try restaurant, for the home-screen widget — a
  /// one-shot query rather than a stream, since the widget asks again each time
  /// it (re)renders instead of observing. Null when nothing is marked
  /// want-to-try.
  Future<Restaurant?> getRandomWantToTry({String? groupId}) => customSelect(
    'SELECT * FROM restaurants WHERE deletedAt IS NULL '
    'AND ${_groupScope.replaceAll('%ALIAS%', 'restaurants')} '
    'AND NOT EXISTS '
    '(SELECT 1 FROM visits WHERE restaurantId = restaurants.id '
    'AND visits.deletedAt IS NULL) '
    'ORDER BY RANDOM() LIMIT 1',
    variables: _groupVars(groupId),
    readsFrom: <ResultSetImplementation>{restaurants, visits, restaurantGroups},
  ).getSingleOrNull().then(
    (QueryRow? row) => row == null ? null : restaurants.map(row.data),
  );

  Stream<List<String>> _observeDistinct(String column, {String? groupId}) =>
      customSelect(
        'SELECT DISTINCT $column AS value FROM restaurants '
        'WHERE $column IS NOT NULL AND deletedAt IS NULL '
        'AND ${_groupScope.replaceAll('%ALIAS%', 'restaurants')} '
        'ORDER BY $column COLLATE NOCASE ASC',
        variables: _groupVars(groupId),
        readsFrom: <ResultSetImplementation>{restaurants, restaurantGroups},
      ).watch().map(
        (List<QueryRow> rows) => <String>[
          for (final QueryRow row in rows) row.read<String>('value'),
        ],
      );

  List<Restaurant> _mapRestaurants(List<QueryRow> rows) => <Restaurant>[
    for (final QueryRow row in rows) restaurants.map(row.data),
  ];
}
