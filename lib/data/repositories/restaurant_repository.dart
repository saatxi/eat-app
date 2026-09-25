import 'package:uuid/uuid.dart';

import '../../core/utils/search_normalizer.dart';
import '../db/app_database.dart';
import '../db/daos/photo_dao.dart';
import '../db/daos/restaurant_dao.dart';
import '../db/daos/tag_dao.dart';
import '../db/daos/visit_dao.dart';
import '../models/restaurant_sort.dart';
import '../models/stats_projections.dart';

/// The single, app-facing entry point to the restaurant data.
///
/// It is the Flutter counterpart of the Android app's
/// `RestaurantRepository`/`RoomRestaurantRepository` pair, collapsed into one
/// class: with no Hilt in the picture there is nothing for an interface to be
/// swapped for, and one implementation with one set of names is easier to
/// follow than two files that always change together.
///
/// What it adds on top of the four DAOs is exactly what those deliberately
/// leave out: query folding (a typed search term has to be normalized and its
/// `LIKE` metacharacters escaped before it reaches SQL), the multi-table writes
/// that have to be atomic (a restaurant plus its tags, a visit plus its photos),
/// and the id/timestamp generation that makes those writes complete.
///
/// Deliberately absent for now, because they belong to later blocks: the
/// `backup.json` snapshot the Android repository wrote after every mutation
/// (sharing/importing), and the deletion of photo files from disk (photos).
/// Both are side effects on files, not on the database, so nothing here has to
/// change shape to accommodate them.
class RestaurantRepository {
  RestaurantRepository(this._database);

  final AppDatabase _database;

  static const Uuid _uuid = Uuid();

  late final RestaurantDao _restaurants = _database.restaurantDao;
  late final TagDao _tags = _database.tagDao;
  late final VisitDao _visits = _database.visitDao;
  late final PhotoDao _photos = _database.photoDao;

  // --- Restaurants ----------------------------------------------------------

  /// The list screen's single query.
  ///
  /// [query] arrives as the user typed it; folding it and escaping its wildcards
  /// here rather than at the call site means no screen can forget to do either,
  /// and the `LIKE` against the stored `searchText` column stays a plain
  /// substring match. A blank filter is the same as no filter, which is also
  /// true of every other argument.
  Stream<List<Restaurant>> observeFiltered({
    String? query,
    int? minRating,
    String? cuisineType,
    RestaurantSort sort = RestaurantSort.name,
    bool? visited,
    String? city,
    String? region,
    String? country,
    int? priceRange,
  }) {
    final String? foldedQuery = _foldQuery(query);

    return _restaurants.observeFiltered(
      query: foldedQuery,
      minRating: minRating,
      cuisineType: _blankToNull(cuisineType),
      // The DAO takes a flag rather than the enum, so the ordering stays a bound
      // parameter instead of SQL assembled from a value.
      sortByRating: sort == RestaurantSort.rating,
      visited: visited,
      city: _blankToNull(city),
      region: _blankToNull(region),
      country: _blankToNull(country),
      priceRange: priceRange,
    );
  }

  Stream<List<String>> observeCuisineTypes() => _restaurants.observeCuisineTypes();

  Stream<List<String>> observeCities() => _restaurants.observeCities();

  Stream<List<String>> observeRegions() => _restaurants.observeRegions();

  Stream<List<String>> observeCountries() => _restaurants.observeCountries();

  Stream<Restaurant?> observeById(String id) => _restaurants.observeById(id);

  /// [restaurant.id] must already be a freshly generated UUID and its
  /// `searchText` already built with `buildSearchText` — both are the caller's
  /// contract on the Android side too, and the edit screen owns them because it
  /// is the only place that has the untrimmed form values in hand.
  ///
  /// [tags] replaces any the restaurant already had, in the same transaction as
  /// the row itself: a half-saved restaurant with the old tags is not a state
  /// worth being able to observe.
  Future<void> insert(
    Restaurant restaurant, {
    List<String> tags = const <String>[],
  }) async {
    await _database.transaction(() async {
      await _restaurants.insertRestaurant(restaurant);
      await _tags.setTags(restaurant.id, tags);
    });
  }

  /// Same contract as [insert]; the row must already exist.
  Future<void> update(Restaurant restaurant, List<String> tags) async {
    await _database.transaction(() async {
      await _restaurants.updateRestaurant(restaurant);
      await _tags.setTags(restaurant.id, tags);
    });
  }

  /// No explicit tag/visit/photo cleanup: they all cascade on delete.
  Future<void> delete(String id) => _restaurants.deleteRestaurant(id);

  Future<void> deleteAll() async {
    await _database.transaction(() async {
      await _restaurants.deleteAllRestaurants();
      // The cascade only clears restaurant_tags when restaurants are deleted —
      // the tags table itself needs its own wipe.
      await _tags.deleteAllTags();
    });
  }

  // --- Tags -----------------------------------------------------------------

  Stream<List<String>> observeAllTagNames() => _tags.observeAllTagNames();

  Stream<List<String>> observeTagNames(String restaurantId) =>
      _tags.observeTagNames(restaurantId);

  /// Keyed by restaurant id, for the list rows that show a restaurant's tags.
  Stream<Map<String, List<String>>> observeTagsByRestaurantId() =>
      _tags.observeAllRestaurantTagLinks().map(
        (List<RestaurantTagName> links) {
          final Map<String, List<String>> byRestaurant =
              <String, List<String>>{};
          for (final RestaurantTagName link in links) {
            (byRestaurant[link.restaurantId] ??= <String>[]).add(link.name);
          }
          return byRestaurant;
        },
      );

  // --- Statistics -----------------------------------------------------------

  Stream<int> observeTotalCount() => _restaurants.observeTotalCount();

  Stream<int> observeVisitedCount() => _visits.observeVisitedCount();

  Stream<double?> observeAverageRating() => _visits.observeAverageRating();

  Stream<List<CuisineCount>> observeCuisineCounts() =>
      _restaurants.observeCuisineCounts();

  Stream<List<PriceRangeCount>> observePriceRangeCounts() =>
      _restaurants.observePriceRangeCounts();

  Stream<List<TagCount>> observeTagCounts() => _tags.observeTagCounts();

  /// Every visit's raw epoch-millis date, across every restaurant — bucketed
  /// into months by the statistics screen, which is why this is the raw list.
  Stream<List<int>> observeAllVisitDates() => _visits.observeAllVisitDates();

  /// Every visit's raw date and rating, for the monthly-average chart.
  Stream<List<VisitDateRating>> observeAllVisitDateRatings() =>
      _visits.observeAllVisitDateRatings();

  /// One random want-to-try restaurant, for the home-screen widget. A one-shot
  /// query rather than a stream, since the widget asks again each time it
  /// (re)renders instead of observing. Null when nothing is want-to-try.
  Future<Restaurant?> getRandomWantToTry() => _restaurants.getRandomWantToTry();

  // --- Visits ---------------------------------------------------------------

  Stream<List<Visit>> observeVisitsForRestaurant(String restaurantId) =>
      _visits.observeVisitsForRestaurant(restaurantId);

  /// Every restaurant's most recent visit, keyed by restaurant id — backs the
  /// list, favourites and roulette rows.
  Stream<Map<String, Visit>> observeLatestVisitByRestaurantId() => _visits
      .observeLatestVisitByRestaurantId()
      .map(
        (List<Visit> visits) => <String, Visit>{
          for (final Visit visit in visits) visit.restaurantId: visit,
        },
      );

  Future<Visit?> getLatestVisit(String restaurantId) =>
      _visits.getLatestVisit(restaurantId);

  /// Replaces every visit a restaurant has with zero-or-one, matching the single
  /// rating the edit form collects: [visited] false clears them all, true writes
  /// one with [rating]/[notes], reusing the existing visit's identity and date
  /// when there was one so re-saving the form neither resets the date to "now"
  /// nor makes the row look new.
  Future<void> saveSingleVisit({
    required String restaurantId,
    required bool visited,
    required int rating,
    String? notes,
  }) async {
    await _database.transaction(() async {
      final Visit? existing = await _visits.getLatestVisit(restaurantId);
      await _visits.deleteAllVisitsForRestaurant(restaurantId);
      if (visited) {
        await _visits.insertVisit(
          Visit(
            id: existing?.id ?? _uuid.v4(),
            restaurantId: restaurantId,
            visitDate: existing?.visitDate ?? DateTime.now().millisecondsSinceEpoch,
            rating: rating,
            notes: notes,
            // Carried over rather than taken from the form, which doesn't ask:
            // dropping it would silently lose the price band on every re-save.
            priceRange: existing?.priceRange ?? 0,
          ),
        );
      }
    });
  }

  /// Adds one more visit, together with any photos taken on it. Returns the new
  /// visit's id.
  ///
  /// This is the real, multi-visit-per-restaurant path the log-visit screen
  /// uses; import replays a whole history through it, one visit at a time.
  Future<String> addVisit({
    required String restaurantId,
    required int visitDate,
    required int rating,
    String? notes,
    int priceRange = 0,
    List<String> photoPaths = const <String>[],
  }) async {
    final String visitId = _uuid.v4();
    await _database.transaction(() async {
      await _visits.insertVisit(
        Visit(
          id: visitId,
          restaurantId: restaurantId,
          visitDate: visitDate,
          rating: rating,
          notes: notes,
          priceRange: priceRange,
        ),
      );
      for (final (int index, String path) in photoPaths.indexed) {
        await _photos.insertPhoto(
          Photo(id: _uuid.v4(), visitId: visitId, path: path, position: index),
        );
      }
    });
    return visitId;
  }

  Future<void> deleteVisit(String id) => _visits.deleteVisit(id);

  // --- Photos ---------------------------------------------------------------

  Stream<List<Photo>> observePhotosForRestaurant(String restaurantId) =>
      _photos.observePhotosForRestaurant(restaurantId);

  Stream<List<Photo>> observePhotosForVisit(String visitId) =>
      _photos.observePhotosForVisit(visitId);

  /// The first restaurant-level photo, if any — used to prefill the edit form
  /// and to show a single thumbnail in the list.
  Future<String?> getRestaurantPhotoPath(String restaurantId) async =>
      (await _photos.getFirstPhotoForRestaurant(restaurantId))?.path;

  /// Appends [photoPaths] after whatever the restaurant already has. A no-op for
  /// an empty list, so a caller that simply passes "the photos I collected"
  /// doesn't have to special-case having collected none.
  Future<void> addRestaurantPhotos(
    String restaurantId,
    List<String> photoPaths,
  ) async {
    if (photoPaths.isEmpty) {
      return;
    }
    final int startPosition =
        await _photos.getMaxPositionForRestaurant(restaurantId) + 1;
    await _database.transaction(() async {
      for (final (int index, String path) in photoPaths.indexed) {
        await _photos.insertPhoto(
          Photo(
            id: _uuid.v4(),
            restaurantId: restaurantId,
            path: path,
            position: startPosition + index,
          ),
        );
      }
    });
  }

  /// Deletes one photo row (restaurant- or visit-level). The file it points at
  /// is left on disk for now — removing it belongs with the rest of the photo
  /// storage work.
  Future<void> deletePhoto(String id) => _photos.deletePhoto(id);

  // --- Helpers --------------------------------------------------------------

  /// Folds and escapes a raw search term, or null when there is nothing left to
  /// search for.
  String? _foldQuery(String? query) {
    if (query == null || query.trim().isEmpty) {
      return null;
    }
    return escapeLikeWildcards(normalizeForSearch(query));
  }

  static String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}
