import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/daos/photo_dao.dart';
import '../db/daos/visit_dao.dart';
import '../sync/shared_write.dart';
import '../sync/sync_table.dart';
import 'write_effects.dart';

/// A restaurant's visit timeline: logging, editing and deleting a visit,
/// together with whatever photos it carries.
class VisitRepository {
  VisitRepository(this._database, this._effects);

  final AppDatabase _database;
  final WriteEffects _effects;

  static const Uuid _uuid = Uuid();

  late final VisitDao _visits = _database.visitDao;
  late final PhotoDao _photos = _database.photoDao;

  Stream<List<Visit>> observeVisitsForRestaurant(String restaurantId) =>
      _visits.observeVisitsForRestaurant(restaurantId);

  /// Every restaurant's most recent visit, keyed by restaurant id — backs
  /// the list, favourites and roulette rows.
  Stream<Map<String, Visit>> observeLatestVisitByRestaurantId({
    String? groupId,
  }) => _visits
      .observeLatestVisitByRestaurantId(groupId: groupId)
      .map(
        (List<Visit> visits) => <String, Visit>{
          for (final Visit visit in visits) visit.restaurantId: visit,
        },
      );

  Future<Visit?> getLatestVisit(String restaurantId) =>
      _visits.getLatestVisit(restaurantId);

  /// Adds one more visit, together with any photos taken on it. Returns the
  /// new visit's id.
  ///
  /// [photoSourcePaths] are the temporary paths the picker returned; each is
  /// persisted through [WriteEffects.photoStorage] first (outside the
  /// transaction, since it touches the disk) and it is the stored copy that
  /// goes in the database.
  ///
  /// This is the real, multi-visit-per-restaurant path the log-visit screen
  /// uses; import replays a whole history through it, one visit at a time,
  /// with no photos of its own.
  /// Passing [shared] attributes the visit and its photos to a group and
  /// queues them; without it the write is private, exactly as before.
  Future<String> addVisit({
    required String restaurantId,
    required int visitDate,
    required int rating,
    String? notes,
    int priceRange = 0,
    List<String> photoSourcePaths = const <String>[],
    SharedWrite? shared,
  }) async {
    final List<String> storedPaths = <String>[
      for (final String sourcePath in photoSourcePaths)
        await _effects.photoStorage?.persist(sourcePath) ?? sourcePath,
    ];
    final String visitId = _uuid.v4();
    final List<String> photoIds = <String>[
      for (final String _ in storedPaths) _uuid.v4(),
    ];
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      await _visits.insertVisit(
        Visit(
          id: visitId,
          restaurantId: restaurantId,
          visitDate: visitDate,
          rating: rating,
          notes: notes,
          priceRange: priceRange,
          groupId: shared?.groupId,
          createdBy: shared?.createdBy,
          updatedAt: now,
        ),
      );
      for (final (int index, String path) in storedPaths.indexed) {
        await _photos.insertPhoto(
          Photo(
            id: photoIds[index],
            visitId: visitId,
            path: path,
            position: index,
            groupId: shared?.groupId,
            createdBy: shared?.createdBy,
            updatedAt: now,
          ),
        );
      }
      if (shared != null) {
        await _effects.pending.enqueue(
          SyncTable.visits,
          visitId,
          shared.groupId,
        );
        for (final String photoId in photoIds) {
          await _effects.pending.enqueue(
            SyncTable.photos,
            photoId,
            shared.groupId,
          );
        }
      }
    });
    await _effects.afterWrite();
    _effects.notifySharedWrite(shared?.groupId);
    return visitId;
  }

  /// Rewrites an existing visit in place: its fields, and which photos it
  /// carries. A no-op when [visitId] names nothing (the visit was deleted
  /// from under the form).
  ///
  /// [keptPhotoIds] are the ids of the photos the form still shows, so
  /// anything the visit has that is *not* listed was removed by the user;
  /// [addedPhotoSourcePaths] are the temporary paths the picker returned
  /// since, persisted through [WriteEffects.photoStorage] exactly as
  /// [addVisit] does. The visit's id, restaurant and group never move: an
  /// edit changes what the visit says, never whose it is.
  ///
  /// The shared branch mirrors [deleteVisit]: a removed photo is tombstoned
  /// and queued rather than dropped, and its file is left on disk for the
  /// sync layer, while a private one goes with its file.
  Future<void> updateVisit({
    required String visitId,
    required int visitDate,
    required int rating,
    String? notes,
    int priceRange = 0,
    List<String> keptPhotoIds = const <String>[],
    List<String> addedPhotoSourcePaths = const <String>[],
    SharedWrite? shared,
  }) async {
    final Visit? existing = await _visits.getById(visitId);
    if (existing == null) {
      return;
    }
    final List<Photo> current = await _photos.getPhotosForVisit(visitId);
    final Set<String> kept = keptPhotoIds.toSet();
    final List<Photo> removed = <Photo>[
      for (final Photo photo in current)
        if (!kept.contains(photo.id)) photo,
    ];
    final List<String> storedPaths = <String>[
      for (final String sourcePath in addedPhotoSourcePaths)
        await _effects.photoStorage?.persist(sourcePath) ?? sourcePath,
    ];
    final List<String> photoIds = <String>[
      for (final String _ in storedPaths) _uuid.v4(),
    ];
    // Appended after whatever survived, so the strip keeps the order the
    // form showed rather than reshuffling on every save.
    int position = current.fold<int>(
      -1,
      (int max, Photo photo) => photo.position > max ? photo.position : max,
    );
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      await _visits.updateVisit(
        existing.copyWith(
          visitDate: visitDate,
          rating: rating,
          notes: Value<String?>(notes),
          priceRange: priceRange,
          updatedAt: now,
        ),
      );
      for (final Photo photo in removed) {
        if (shared == null) {
          await _photos.deletePhoto(photo.id);
        } else {
          await _photos.softDeletePhoto(photo.id, now);
          await _effects.pending.enqueue(
            SyncTable.photos,
            photo.id,
            shared.groupId,
          );
        }
      }
      for (final (int index, String path) in storedPaths.indexed) {
        await _photos.insertPhoto(
          Photo(
            id: photoIds[index],
            visitId: visitId,
            path: path,
            position: ++position,
            groupId: shared?.groupId,
            createdBy: shared?.createdBy,
            updatedAt: now,
          ),
        );
      }
      if (shared != null) {
        await _effects.pending.enqueue(
          SyncTable.visits,
          visitId,
          shared.groupId,
        );
        for (final String photoId in photoIds) {
          await _effects.pending.enqueue(
            SyncTable.photos,
            photoId,
            shared.groupId,
          );
        }
      }
    });
    if (shared == null) {
      await _effects.deleteFiles(removed);
    }
    await _effects.afterWrite();
    _effects.notifySharedWrite(shared?.groupId);
  }

  /// For a private visit, the photo rows cascade away with it and their
  /// files are read back first so they can be removed from disk too. A
  /// shared visit and its photos are tombstoned (and queued) instead, never
  /// removed.
  Future<void> deleteVisit(String id) async {
    final Visit? row = await _visits.getById(id);
    final List<Photo> photos = await _photos.getPhotosForVisit(id);
    final String? groupId = row?.groupId;
    if (groupId != null) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      await _database.transaction(() async {
        await _visits.softDeleteVisit(id, now);
        await _photos.softDeletePhotosForVisit(id, now);
        await _effects.pending.enqueue(SyncTable.visits, id, groupId);
        for (final Photo photo in photos) {
          await _effects.pending.enqueue(SyncTable.photos, photo.id, groupId);
        }
      });
      await _effects.afterWrite();
      _effects.notifySharedWrite(groupId);
      return;
    }
    await _visits.deleteVisit(id);
    await _effects.deleteFiles(photos);
    await _effects.afterWrite();
  }
}
