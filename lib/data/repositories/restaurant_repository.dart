import 'package:drift/drift.dart' show Value;

import '../../core/utils/search_normalizer.dart';
import '../db/app_database.dart';
import '../db/daos/photo_dao.dart';
import '../db/daos/restaurant_dao.dart';
import '../db/daos/visit_dao.dart';
import '../models/restaurant_sort.dart';
import '../models/stats_projections.dart';
import '../photo/photo_storage.dart';
import '../share/backup_writer.dart';
import '../share/restaurant_share_models.dart';
import '../sync/shared_write.dart';
import '../sync/sync_table.dart';
import 'group_membership_repository.dart';
import 'photo_repository.dart';
import 'restaurant_exporter.dart';
import 'stats_repository.dart';
import 'visit_repository.dart';
import 'write_effects.dart';

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
/// that have to be atomic (a visit plus its photos), and the id/timestamp
/// generation that makes those writes complete.
///
/// This class itself holds only the restaurant queries and CRUD; visits,
/// photos, group membership, statistics and export each moved to their own
/// file ([VisitRepository], [PhotoRepository], [GroupMembershipRepository],
/// [StatsRepository], [RestaurantExporter]) once this grew past 1000 lines.
/// It composes all five internally and forwards their public methods
/// unchanged, so every existing call site keeps working exactly as before —
/// a caller with a direct need for just one of them can still construct it
/// on its own, passing the same [WriteEffects] this repository builds.
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
    this.favoriteIds,
    this.onSharedWrite,
  }) {
    final RestaurantExporter exporter = RestaurantExporter(
      _database,
      favoriteIds: favoriteIds,
    );
    _exporter = exporter;
    _effects = WriteEffects(
      _database,
      exportAll: exporter.exportRestaurants,
      backupWriter: backupWriter,
      photoStorage: photoStorage,
      onChanged: onChanged,
      onSharedWrite: onSharedWrite,
    );
    _groupMembership = GroupMembershipRepository(_database, _effects);
    _visitRepository = VisitRepository(_database, _effects);
    _photoRepository = PhotoRepository(_database, _effects);
    _statsRepository = StatsRepository(_database);
  }

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

  /// The ids the user has marked favourite, or null when nothing holds a
  /// preference store — the case in every unit test. A callback rather than a
  /// set, because favourites change while this repository lives and are not a
  /// restaurant column at all: reading it at export time keeps the file and the
  /// automatic snapshot from ever carrying a stale flag.
  final Set<String> Function()? favoriteIds;

  /// Called with a group id after a write that produced a shared row, so the
  /// app can push it to the group right away instead of waiting for a manual
  /// sync or the next launch. Kept as a bare callback (not the sync service
  /// itself) so this layer still knows nothing about the transport. Null in
  /// every unit test and in personal mode, where a shared write cannot happen.
  final void Function(String groupId)? onSharedWrite;

  late final RestaurantExporter _exporter;
  late final WriteEffects _effects;
  late final GroupMembershipRepository _groupMembership;
  late final VisitRepository _visitRepository;
  late final PhotoRepository _photoRepository;
  late final StatsRepository _statsRepository;

  late final RestaurantDao _restaurants = _database.restaurantDao;
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
  ///
  /// [groupId] is the scope: a group id shows that group's rows, null the
  /// private ones. Every collection query below takes the same argument.
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
    String? groupId,
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
      groupId: groupId,
    );
  }

  Stream<List<String>> observeCuisineTypes({String? groupId}) =>
      _restaurants.observeCuisineTypes(groupId: groupId);

  Stream<List<String>> observeCities({String? groupId}) =>
      _restaurants.observeCities(groupId: groupId);

  Stream<List<String>> observeRegions({String? groupId}) =>
      _restaurants.observeRegions(groupId: groupId);

  Stream<List<String>> observeCountries({String? groupId}) =>
      _restaurants.observeCountries(groupId: groupId);

  Stream<Restaurant?> observeById(String id) => _restaurants.observeById(id);

  /// Every restaurant, as a one-shot read — the import review flags duplicates
  /// against this, and it has no stream of its own to subscribe to.
  Future<List<Restaurant>> getAllRestaurants() => _restaurants.getAll();

  /// [restaurant.id] must already be a freshly generated UUID and its
  /// `searchText` already built with `buildSearchText` — both are the caller's
  /// contract on the Android side too, and the edit screen owns them because it
  /// is the only place that has the untrimmed form values in hand.
  ///
  /// A shared row (`groupId` set) is queued in the same transaction, so it is
  /// pushed on the next sync; a private one is written exactly as before.
  Future<void> insert(Restaurant restaurant) async {
    await _database.transaction(() async {
      await _restaurants.insertRestaurant(restaurant);
      await _effects.enqueueIfShared(
        SyncTable.restaurants,
        restaurant.id,
        restaurant.groupId,
      );
      await _groupMembership.recordMembership(restaurant);
    });
    await _effects.afterWrite();
    _effects.notifySharedWrite(restaurant.groupId);
  }

  /// Same contract as [insert]; the row must already exist.
  Future<void> update(Restaurant restaurant) async {
    await _database.transaction(() async {
      await _restaurants.updateRestaurant(restaurant);
      await _effects.enqueueIfShared(
        SyncTable.restaurants,
        restaurant.id,
        restaurant.groupId,
      );
      await _groupMembership.recordMembership(restaurant);
    });
    await _effects.afterWrite();
    _effects.notifySharedWrite(restaurant.groupId);
  }

  /// Deletes a restaurant: hard for a private one, softly for a shared one.
  ///
  /// A private row's visits and photos all cascade on delete; only their photo
  /// *files* are read back first, since the cascade knows nothing about the
  /// disk. A shared row is tombstoned instead (see [_softDeleteSharedRestaurant])
  /// so the deletion can reach every member on the next push.
  Future<void> delete(String id) async {
    final Restaurant? row = await _restaurants.getById(id);
    if (row != null && row.groupId != null) {
      await _softDeleteSharedRestaurant(row);
      await _effects.afterWrite();
      _effects.notifySharedWrite(row.groupId);
      return;
    }
    final List<Photo> photos = await _photos.getAllPhotosForRestaurant(id);
    await _restaurants.deleteRestaurant(id);
    await _effects.deleteFiles(photos);
    await _effects.afterWrite();
  }

  Future<void> deleteAll() async {
    final List<Photo> photos = await _photos.getAllPersonalPhotos();
    await _restaurants.deleteAllPersonalRestaurants();
    await _effects.deleteFiles(photos);
    await _effects.afterWrite();
  }

  /// Removes every local trace of [groupId]: its shared rows and their photo
  /// files, the pending-sync queue entries and the pull cursor.
  ///
  /// Called when a group is deleted or left. A deleted group is gone on the
  /// server (the foreign keys cascade), so no tombstone ever reaches this
  /// device to clean its rows up — without this they would linger as orphans
  /// under a `groupId` that no longer names any group.
  Future<void> purgeGroup(String groupId) async {
    final List<Photo> photos = await (_database.select(_database.photos)
          ..where((t) => t.groupId.equals(groupId)))
        .get();
    await _database.transaction(() async {
      await (_database.delete(_database.restaurantGroups)
            ..where((t) => t.groupId.equals(groupId)))
          .go();
      await (_database.delete(_database.photos)
            ..where((t) => t.groupId.equals(groupId)))
          .go();
      await (_database.delete(_database.visits)
            ..where((t) => t.groupId.equals(groupId)))
          .go();
      await (_database.delete(_database.restaurants)
            ..where((t) => t.groupId.equals(groupId)))
          .go();
      await (_database.delete(_database.pendingSyncs)
            ..where((t) => t.groupId.equals(groupId)))
          .go();
      await (_database.delete(_database.syncCursors)
            ..where((t) => t.groupId.equals(groupId)))
          .go();
    });
    await _effects.deleteFiles(photos);
    await _effects.afterWrite();
  }

  // --- Group membership (see GroupMembershipRepository) ----------------------

  Future<List<String>> groupIdsForRestaurant(String restaurantId) =>
      _groupMembership.groupIdsForRestaurant(restaurantId);

  Future<void> setRestaurantGroups({
    required String restaurantId,
    required Set<String> groupIds,
    required String createdBy,
  }) => _groupMembership.setRestaurantGroups(
    restaurantId: restaurantId,
    groupIds: groupIds,
    createdBy: createdBy,
  );

  Future<void> addRestaurantsToGroups({
    required Set<String> restaurantIds,
    required Set<String> groupIds,
    required String createdBy,
  }) => _groupMembership.addRestaurantsToGroups(
    restaurantIds: restaurantIds,
    groupIds: groupIds,
    createdBy: createdBy,
  );

  Future<List<Restaurant>> likelyGroupDuplicates({
    required Iterable<Restaurant> candidates,
    required Set<String> groupIds,
  }) => _groupMembership.likelyGroupDuplicates(
    candidates: candidates,
    groupIds: groupIds,
  );

  Future<List<Restaurant>> likelyGroupDuplicatesOf({
    required Set<String> restaurantIds,
    required Set<String> groupIds,
  }) => _groupMembership.likelyGroupDuplicatesOf(
    restaurantIds: restaurantIds,
    groupIds: groupIds,
  );

  // --- Sharing (see RestaurantExporter) --------------------------------------

  Future<List<RestaurantExport>> exportRestaurants({
    List<String>? restaurantIds,
    bool includeVisits = true,
    String? groupId,
  }) => _exporter.exportRestaurants(
    restaurantIds: restaurantIds,
    includeVisits: includeVisits,
    groupId: groupId,
  );

  // --- Statistics (see StatsRepository) ---------------------------------------

  Stream<int> observeTotalCount({String? groupId}) =>
      _statsRepository.observeTotalCount(groupId: groupId);

  Stream<int> observeVisitedCount({String? groupId}) =>
      _statsRepository.observeVisitedCount(groupId: groupId);

  Stream<double?> observeAverageRating({String? groupId}) =>
      _statsRepository.observeAverageRating(groupId: groupId);

  Stream<List<CuisineCount>> observeCuisineCounts({String? groupId}) =>
      _statsRepository.observeCuisineCounts(groupId: groupId);

  Stream<List<PriceRangeCount>> observePriceRangeCounts({String? groupId}) =>
      _statsRepository.observePriceRangeCounts(groupId: groupId);

  Stream<List<int>> observeAllVisitDates({String? groupId}) =>
      _statsRepository.observeAllVisitDates(groupId: groupId);

  Stream<List<VisitDateRating>> observeAllVisitDateRatings({
    String? groupId,
  }) => _statsRepository.observeAllVisitDateRatings(groupId: groupId);

  Future<Restaurant?> getRandomWantToTry({String? groupId}) =>
      _statsRepository.getRandomWantToTry(groupId: groupId);

  // --- Visits (see VisitRepository) -------------------------------------------

  Stream<List<Visit>> observeVisitsForRestaurant(String restaurantId) =>
      _visitRepository.observeVisitsForRestaurant(restaurantId);

  Stream<Map<String, Visit>> observeLatestVisitByRestaurantId({
    String? groupId,
  }) => _visitRepository.observeLatestVisitByRestaurantId(groupId: groupId);

  Future<Visit?> getLatestVisit(String restaurantId) =>
      _visitRepository.getLatestVisit(restaurantId);

  Future<String> addVisit({
    required String restaurantId,
    required int visitDate,
    required int rating,
    String? notes,
    int priceRange = 0,
    List<String> photoSourcePaths = const <String>[],
    SharedWrite? shared,
  }) => _visitRepository.addVisit(
    restaurantId: restaurantId,
    visitDate: visitDate,
    rating: rating,
    notes: notes,
    priceRange: priceRange,
    photoSourcePaths: photoSourcePaths,
    shared: shared,
  );

  Future<void> updateVisit({
    required String visitId,
    required int visitDate,
    required int rating,
    String? notes,
    int priceRange = 0,
    List<String> keptPhotoIds = const <String>[],
    List<String> addedPhotoSourcePaths = const <String>[],
    SharedWrite? shared,
  }) => _visitRepository.updateVisit(
    visitId: visitId,
    visitDate: visitDate,
    rating: rating,
    notes: notes,
    priceRange: priceRange,
    keptPhotoIds: keptPhotoIds,
    addedPhotoSourcePaths: addedPhotoSourcePaths,
    shared: shared,
  );

  Future<void> deleteVisit(String id) => _visitRepository.deleteVisit(id);

  // --- Photos (see PhotoRepository) -------------------------------------------

  Stream<List<Photo>> observePhotosForRestaurant(String restaurantId) =>
      _photoRepository.observePhotosForRestaurant(restaurantId);

  Stream<List<Photo>> observePhotosForVisit(String visitId) =>
      _photoRepository.observePhotosForVisit(visitId);

  Stream<Map<String, String>> observeRestaurantPhotoPaths({String? groupId}) =>
      _photoRepository.observeRestaurantPhotoPaths(groupId: groupId);

  Future<String?> getRestaurantPhotoPath(String restaurantId) =>
      _photoRepository.getRestaurantPhotoPath(restaurantId);

  Future<void> setRestaurantPhoto(
    String restaurantId,
    String? sourcePath, {
    SharedWrite? shared,
  }) => _photoRepository.setRestaurantPhoto(
    restaurantId,
    sourcePath,
    shared: shared,
  );

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

  /// Tombstones a shared restaurant and everything under it, and queues all of
  /// it so a push tells every member. Local photo files are deliberately left
  /// on disk: the tombstone rows still reference them and there is no purge
  /// step yet to reclaim them.
  Future<void> _softDeleteSharedRestaurant(Restaurant row) async {
    final String groupId = row.groupId!;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<Visit> visits = await _visits.getVisitsForRestaurant(row.id);
    final List<Photo> photos = await _photos.getAllPhotosForRestaurant(row.id);
    final List<RestaurantGroup> memberships = await (_database
            .select(_database.restaurantGroups)
          ..where((t) => t.restaurantId.equals(row.id)))
        .get();
    await _database.transaction(() async {
      await _restaurants.softDeleteRestaurant(row.id, now);
      await _visits.softDeleteVisitsForRestaurant(row.id, now);
      await _photos.softDeletePhotosForRestaurant(row.id, now);
      for (final Visit visit in visits) {
        await _photos.softDeletePhotosForVisit(visit.id, now);
      }
      await _effects.pending.enqueue(SyncTable.restaurants, row.id, groupId);
      // Tombstone every membership the restaurant had, so removing it reaches
      // each group it was shared into, not just its home group.
      for (final RestaurantGroup membership in memberships) {
        await _database.into(_database.restaurantGroups).insertOnConflictUpdate(
          RestaurantGroupsCompanion.insert(
            restaurantId: membership.restaurantId,
            groupId: membership.groupId,
            createdBy: membership.createdBy,
            updatedAt: Value<int>(now),
            deletedAt: Value<int>(now),
          ),
        );
        await _effects.pending.enqueue(
          SyncTable.restaurantGroups,
          membership.restaurantId,
          membership.groupId,
        );
      }
      for (final Visit visit in visits) {
        await _effects.pending.enqueue(SyncTable.visits, visit.id, groupId);
      }
      for (final Photo photo in photos) {
        await _effects.pending.enqueue(SyncTable.photos, photo.id, groupId);
      }
    });
  }
}
