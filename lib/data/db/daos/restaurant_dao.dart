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
@DriftAccessor(tables: <Type>[Restaurants, Visits])
class RestaurantDao extends DatabaseAccessor<AppDatabase>
    with _$RestaurantDaoMixin {
  RestaurantDao(super.db);

  /// The list screen's single query.
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
  }) {
    final int? visitedFlag = visited == null ? null : (visited ? 1 : 0);

    return customSelect(
      'SELECT * FROM restaurants r '
      "WHERE (? IS NULL OR searchText LIKE '%' || ? || '%' ESCAPE '\\') "
      'AND (? IS NULL OR EXISTS (SELECT 1 FROM visits v '
      'WHERE v.restaurantId = r.id AND v.rating >= ?)) '
      'AND (? IS NULL OR cuisineType = ?) '
      'AND (? IS NULL '
      'OR (? = 1 AND EXISTS (SELECT 1 FROM visits v WHERE v.restaurantId = r.id)) '
      'OR (? = 0 AND NOT EXISTS (SELECT 1 FROM visits v WHERE v.restaurantId = r.id))) '
      'AND (? IS NULL OR city = ?) '
      'AND (? IS NULL OR region = ?) '
      'AND (? IS NULL OR country = ?) '
      'AND (? IS NULL OR priceRange = ?) '
      'ORDER BY CASE WHEN ? THEN '
      '(SELECT MAX(v2.rating) FROM visits v2 WHERE v2.restaurantId = r.id) '
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
        Variable<bool>(sortByRating),
      ],
      readsFrom: <ResultSetImplementation>{restaurants, visits},
    ).watch().map(_mapRestaurants);
  }

  /// The cuisine keys actually present in the data, so the filter row can offer
  /// only those instead of all 24 entries of the vocabulary.
  Stream<List<String>> observeCuisineTypes() => customSelect(
    'SELECT DISTINCT cuisineType AS cuisineType FROM restaurants',
    readsFrom: <ResultSetImplementation>{restaurants},
  ).watch().map(
    (List<QueryRow> rows) => <String>[
      for (final QueryRow row in rows) row.read<String>('cuisineType'),
    ],
  );

  /// Distinct, non-null city values actually present, for the location filter
  /// panel.
  Stream<List<String>> observeCities() => _observeDistinct('city');

  /// Distinct, non-null region values actually present, for the location filter
  /// panel.
  Stream<List<String>> observeRegions() => _observeDistinct('region');

  /// Distinct, non-null country values actually present, for the location
  /// filter panel.
  Stream<List<String>> observeCountries() => _observeDistinct('country');

  Stream<Restaurant?> observeById(String id) => customSelect(
    'SELECT * FROM restaurants WHERE id = ?',
    variables: <Variable<Object>>[Variable<String>(id)],
    readsFrom: <ResultSetImplementation>{restaurants},
  ).watchSingleOrNull().map(
    (QueryRow? row) => row == null ? null : restaurants.map(row.data),
  );

  /// A one-shot snapshot of every row, used to write the full backup file after
  /// each write.
  Future<List<Restaurant>> getAll() => customSelect(
    'SELECT * FROM restaurants ORDER BY name COLLATE NOCASE ASC',
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

  // --- Statistics -----------------------------------------------------------

  Stream<int> observeTotalCount() => customSelect(
    'SELECT COUNT(*) AS count FROM restaurants',
    readsFrom: <ResultSetImplementation>{restaurants},
  ).watchSingle().map((QueryRow row) => row.read<int>('count'));

  Stream<List<CuisineCount>> observeCuisineCounts() => customSelect(
    'SELECT cuisineType AS cuisineType, COUNT(*) AS count FROM restaurants '
    'GROUP BY cuisineType ORDER BY count DESC',
    readsFrom: <ResultSetImplementation>{restaurants},
  ).watch().map(
    (List<QueryRow> rows) => <CuisineCount>[
      for (final QueryRow row in rows)
        CuisineCount(
          cuisineType: row.read<String>('cuisineType'),
          count: row.read<int>('count'),
        ),
    ],
  );

  Stream<List<PriceRangeCount>> observePriceRangeCounts() => customSelect(
    'SELECT priceRange AS priceRange, COUNT(*) AS count FROM restaurants '
    'GROUP BY priceRange',
    readsFrom: <ResultSetImplementation>{restaurants},
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
  Future<Restaurant?> getRandomWantToTry() => customSelect(
    'SELECT * FROM restaurants WHERE NOT EXISTS '
    '(SELECT 1 FROM visits WHERE restaurantId = restaurants.id) '
    'ORDER BY RANDOM() LIMIT 1',
    readsFrom: <ResultSetImplementation>{restaurants, visits},
  ).getSingleOrNull().then(
    (QueryRow? row) => row == null ? null : restaurants.map(row.data),
  );

  Stream<List<String>> _observeDistinct(String column) => customSelect(
    'SELECT DISTINCT $column AS value FROM restaurants '
    'WHERE $column IS NOT NULL ORDER BY $column COLLATE NOCASE ASC',
    readsFrom: <ResultSetImplementation>{restaurants},
  ).watch().map(
    (List<QueryRow> rows) => <String>[
      for (final QueryRow row in rows) row.read<String>('value'),
    ],
  );

  List<Restaurant> _mapRestaurants(List<QueryRow> rows) => <Restaurant>[
    for (final QueryRow row in rows) restaurants.map(row.data),
  ];
}
