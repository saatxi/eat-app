import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/daos/photo_dao.dart';
import '../sync/shared_write.dart';
import '../sync/sync_table.dart';
import 'write_effects.dart';

/// A restaurant's own photo — at most one, shown as the list thumbnail and
/// the detail header's fallback when there is no cuisine art. Visit photos
/// are reached through [VisitRepository] instead, since each lives and dies
/// with the visit that took it.
class PhotoRepository {
  PhotoRepository(this._database, this._effects);

  final AppDatabase _database;
  final WriteEffects _effects;

  static const Uuid _uuid = Uuid();

  late final PhotoDao _photos = _database.photoDao;

  Stream<List<Photo>> observePhotosForRestaurant(String restaurantId) =>
      _photos.observePhotosForRestaurant(restaurantId);

  Stream<List<Photo>> observePhotosForVisit(String visitId) =>
      _photos.observePhotosForVisit(visitId);

  /// One restaurant-level photo per restaurant that has one, keyed by id —
  /// the thumbnail the list and roulette rows draw.
  Stream<Map<String, String>> observeRestaurantPhotoPaths({
    String? groupId,
  }) => _photos.observeRestaurantPhotoPaths(groupId: groupId);

  /// The first restaurant-level photo, if any — used to prefill the edit
  /// form and to show a single thumbnail in the list.
  Future<String?> getRestaurantPhotoPath(String restaurantId) async =>
      (await _photos.getFirstPhotoForRestaurant(restaurantId))?.path;

  /// Replaces a restaurant's photo: [sourcePath] is a freshly picked
  /// temporary file to persist, or null to clear the photo. Either way the
  /// restaurant's previous photo file is deleted, so a replace never leaves
  /// the old copy orphaned on disk.
  Future<void> setRestaurantPhoto(
    String restaurantId,
    String? sourcePath, {
    SharedWrite? shared,
  }) async {
    final List<Photo> existing = await _photos.getPhotosForRestaurant(
      restaurantId,
    );
    final String? storedPath = sourcePath == null
        ? null
        : await _effects.photoStorage?.persist(sourcePath) ?? sourcePath;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      if (shared == null) {
        await _photos.deleteAllPhotosForRestaurant(restaurantId);
      } else {
        await _photos.softDeletePhotosForRestaurant(restaurantId, now);
        for (final Photo photo in existing) {
          await _effects.pending.enqueue(
            SyncTable.photos,
            photo.id,
            shared.groupId,
          );
        }
      }
      if (storedPath != null) {
        final String photoId = _uuid.v4();
        await _photos.insertPhoto(
          Photo(
            id: photoId,
            restaurantId: restaurantId,
            path: storedPath,
            position: 0,
            groupId: shared?.groupId,
            createdBy: shared?.createdBy,
            updatedAt: now,
          ),
        );
        if (shared != null) {
          await _effects.pending.enqueue(
            SyncTable.photos,
            photoId,
            shared.groupId,
          );
        }
      }
    });
    await _effects.deleteFiles(existing);
    _effects.notifySharedWrite(shared?.groupId);
  }
}
