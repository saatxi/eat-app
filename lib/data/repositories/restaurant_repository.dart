import 'package:uuid/uuid.dart';

import '../../core/utils/search_normalizer.dart';
import '../db/app_database.dart';
import '../db/daos/photo_dao.dart';
import '../db/daos/restaurant_dao.dart';
import '../db/daos/tag_dao.dart';
import '../db/daos/visit_dao.dart';
import '../models/restaurant_sort.dart';
import '../models/stats_projections.dart';
import '../photo/photo_storage.dart';
import '../share/backup_writer.dart';
import '../share/restaurant_share_models.dart';

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
/// The `backup.json` snapshot the Android repository wrote after every change
/// is written here too, through the optional [BackupWriter] a real app passes
/// in — kept optional so a unit test can build a bare in-memory repository
/// with no platform channel in the way. The photo files behind the `photos`
/// rows are cleaned up through the optional [PhotoStorage], likewise kept
/// optional — a database-only test passes none and the rows cascade on their
/// own, leaving the fake paths on disk untouched.
class RestaurantRepository {
  RestaurantRepository(
    this._database, {
    this.backupWriter,
    this.photoStorage,
    this.onChanged,
  });

  final AppDatabase _database;

  /// Null when nothing should snapshot — the case in every unit test.
  final BackupWriter? backupWriter;

  /// Null when nothing should be deleted from disk — the case in a database-only
  /// test, where the `photos` rows point at paths a fake never created.
  final PhotoStorage? photoStorage;

  /// Called after every write that lands, which is how the home-screen widget
  /// keeps up. Kept as a bare callback rather than a named collaborator so this
  /// layer still knows nothing about the widget plugin — it only says "something
  /// changed" and lets `main` decide who cares. Null in every unit test.
  final Future<void> Function()? onChanged;

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

  /// Every restaurant, as a one-shot read — the import review flags duplicates
  /// against this, and it has no stream of its own to subscribe to.
  Future<List<Restaurant>> getAllRestaurants() => _restaurants.getAll();

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
    await _afterWrite();
  }

  /// Same contract as [insert]; the row must already exist.
  Future<void> update(Restaurant restaurant, List<String> tags) async {
    await _database.transaction(() async {
      await _restaurants.updateRestaurant(restaurant);
      await _tags.setTags(restaurant.id, tags);
    });
    await _afterWrite();
  }

  /// The tag/visit/photo rows all cascade on delete; only their photo *files*
  /// are read back first, since the cascade knows nothing about the disk.
  Future<void> delete(String id) async {
    final List<Photo> photos = await _photos.getAllPhotosForRestaurant(id);
    await _restaurants.deleteRestaurant(id);
    await _deleteFiles(photos);
    await _afterWrite();
  }

  Future<void> deleteAll() async {
    final List<Photo> photos = await _photos.getAllPhotos();
    await _database.transaction(() async {
      await _restaurants.deleteAllRestaurants();
      // The cascade only clears restaurant_tags when restaurants are deleted —
      // the tags table itself needs its own wipe.
      await _tags.deleteAllTags();
    });
    await _deleteFiles(photos);
    await _afterWrite();
  }

  // --- Sharing --------------------------------------------------------------

  /// The exportable shape of every restaurant (or just [restaurantIds]),
  /// carrying each one's tags and — when [includeVisits] is set — its visits.
  ///
  /// Both the shared/exported file and the automatic `backup.json` snapshot are
  /// built from this one method, so the two can't drift apart in what they
  /// consider a restaurant's data.
  Future<List<RestaurantExport>> exportRestaurants({
    List<String>? restaurantIds,
    bool includeVisits = true,
  }) async {
    final List<Restaurant> all = await _restaurants.getAll();
    final List<Restaurant> selected = restaurantIds == null
        ? all
        : <Restaurant>[
            for (final Restaurant restaurant in all)
              if (restaurantIds.contains(restaurant.id)) restaurant,
          ];

    final Map<String, List<String>> tagsByRestaurant = _groupTagNames(
      await _tags.getAllRestaurantTagLinks(),
    );
    final Map<String, List<Visit>> visitsByRestaurant = includeVisits
        ? _groupVisits(await _visits.getAllVisits())
        : const <String, List<Visit>>{};

    return <RestaurantExport>[
      for (final Restaurant restaurant in selected)
        exportRestaurant(
          restaurant,
          tags: tagsByRestaurant[restaurant.id] ?? const <String>[],
          visits: visitsByRestaurant[restaurant.id] ?? const <Visit>[],
        ),
    ];
  }

  /// Runs what a real app wants after every write that lands: the `backup.json`
  /// snapshot, and telling [onChanged] — the home-screen widget — that something
  /// moved. Either is a no-op when its collaborator wasn't supplied, which is
  /// the case in every unit test.
  Future<void> _afterWrite() async {
    final BackupWriter? writer = backupWriter;
    if (writer != null) {
      await writer.write(await exportRestaurants());
    }
    await onChanged?.call();
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
    // The visits being replaced take their photos with them; the restaurant's own
    // photo is not a visit's and is deliberately left alone.
    final List<Photo> removedPhotos = await _photos
        .getVisitPhotosForRestaurant(restaurantId);
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
    await _deleteFiles(removedPhotos);
    await _afterWrite();
  }

  /// Adds one more visit, together with any photos taken on it. Returns the new
  /// visit's id.
  ///
  /// [photoSourcePaths] are the temporary paths the picker returned; each is
  /// persisted through [photoStorage] first (outside the transaction, since it
  /// touches the disk) and it is the stored copy that goes in the database.
  ///
  /// This is the real, multi-visit-per-restaurant path the log-visit screen
  /// uses; import replays a whole history through it, one visit at a time, with
  /// no photos of its own.
  Future<String> addVisit({
    required String restaurantId,
    required int visitDate,
    required int rating,
    String? notes,
    int priceRange = 0,
    List<String> photoSourcePaths = const <String>[],
  }) async {
    final List<String> storedPaths = <String>[
      for (final String sourcePath in photoSourcePaths)
        await photoStorage?.persist(sourcePath) ?? sourcePath,
    ];
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
      for (final (int index, String path) in storedPaths.indexed) {
        await _photos.insertPhoto(
          Photo(id: _uuid.v4(), visitId: visitId, path: path, position: index),
        );
      }
    });
    await _afterWrite();
    return visitId;
  }

  /// The visit's photo rows cascade away with it; their files are read back
  /// first so they can be removed from disk too.
  Future<void> deleteVisit(String id) async {
    final List<Photo> photos = await _photos.getPhotosForVisit(id);
    await _visits.deleteVisit(id);
    await _deleteFiles(photos);
    await _afterWrite();
  }

  // --- Photos ---------------------------------------------------------------

  Stream<List<Photo>> observePhotosForRestaurant(String restaurantId) =>
      _photos.observePhotosForRestaurant(restaurantId);

  Stream<List<Photo>> observePhotosForVisit(String visitId) =>
      _photos.observePhotosForVisit(visitId);

  /// One restaurant-level photo per restaurant that has one, keyed by id — the
  /// thumbnail the list and roulette rows draw.
  Stream<Map<String, String>> observeRestaurantPhotoPaths() =>
      _photos.observeRestaurantPhotoPaths();

  /// The first restaurant-level photo, if any — used to prefill the edit form
  /// and to show a single thumbnail in the list.
  Future<String?> getRestaurantPhotoPath(String restaurantId) async =>
      (await _photos.getFirstPhotoForRestaurant(restaurantId))?.path;

  /// Replaces a restaurant's photo: [sourcePath] is a freshly picked temporary
  /// file to persist, or null to clear the photo. Either way the restaurant's
  /// previous photo file is deleted, so a replace never leaves the old copy
  /// orphaned on disk.
  Future<void> setRestaurantPhoto(String restaurantId, String? sourcePath) async {
    final List<Photo> existing = await _photos.getPhotosForRestaurant(
      restaurantId,
    );
    final String? storedPath = sourcePath == null
        ? null
        : await photoStorage?.persist(sourcePath) ?? sourcePath;
    await _database.transaction(() async {
      await _photos.deleteAllPhotosForRestaurant(restaurantId);
      if (storedPath != null) {
        await _photos.insertPhoto(
          Photo(
            id: _uuid.v4(),
            restaurantId: restaurantId,
            path: storedPath,
            position: 0,
          ),
        );
      }
    });
    await _deleteFiles(existing);
  }

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

  /// Deletes one photo row (restaurant- or visit-level) and the file behind it.
  Future<void> deletePhoto(String id) async {
    final Photo? photo = await _photos.getById(id);
    await _photos.deletePhoto(id);
    if (photo != null) {
      await _deleteFiles(<Photo>[photo]);
    }
  }

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

  static Map<String, List<String>> _groupTagNames(
    List<RestaurantTagName> links,
  ) {
    final Map<String, List<String>> byRestaurant = <String, List<String>>{};
    for (final RestaurantTagName link in links) {
      (byRestaurant[link.restaurantId] ??= <String>[]).add(link.name);
    }
    return byRestaurant;
  }

  static Map<String, List<Visit>> _groupVisits(List<Visit> visits) {
    final Map<String, List<Visit>> byRestaurant = <String, List<Visit>>{};
    for (final Visit visit in visits) {
      (byRestaurant[visit.restaurantId] ??= <Visit>[]).add(visit);
    }
    return byRestaurant;
  }

  /// Removes the files behind [photos], when a storage is configured. Rows are
  /// always gone by the time this runs, so a missing file is simply skipped.
  Future<void> _deleteFiles(List<Photo> photos) async {
    final PhotoStorage? storage = photoStorage;
    if (storage == null || photos.isEmpty) {
      return;
    }
    for (final Photo photo in photos) {
      await storage.delete(photo.path);
    }
  }
}
