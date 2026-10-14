import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../photo/photo_storage.dart';
import 'photo_blob_store.dart';
import 'remote_models.dart';

/// The binary half of syncing a photo: uploading a freshly pushed one before
/// its row, and downloading a freshly pulled one after its row.
///
/// Needs the local [PhotoStorage] and the remote [PhotoBlobStore] together;
/// with either missing (a unit test, a build with no backend) every method
/// here is a no-op and only the row itself syncs.
class PhotoBlobSync {
  PhotoBlobSync({this.photoStorage, this.blobs});

  final PhotoStorage? photoStorage;
  final PhotoBlobStore? blobs;

  /// Uploads each live photo's binary before its row is upserted, so a row
  /// never points at an object that isn't there. A tombstone has no binary
  /// to send.
  Future<void> uploadMissing(List<Photo> rows, List<RemotePhoto> remotes) async {
    final PhotoBlobStore? blobs = this.blobs;
    final PhotoStorage? storage = photoStorage;
    if (blobs == null || storage == null) {
      return;
    }
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].deletedAt != null) {
        continue;
      }
      await blobs.upload(
        remotes[i].storagePath,
        await storage.readBytes(rows[i].path),
      );
    }
  }

  /// Downloads each live remote photo into the local store, returning the
  /// path it landed at, keyed by photo id. Tombstones get no entry.
  ///
  /// A single unreachable or forbidden binary is logged and skipped rather
  /// than aborting the pull: it is the *other* members who download the
  /// photos, so failing the whole batch here would silently starve exactly
  /// the device that did not create the photo — no rows at all, for a photo
  /// that is secondary to them. The row is still applied (without a local
  /// file this time).
  Future<Map<String, String>> downloadAll(List<RemotePhoto> photos) async {
    final PhotoBlobStore? blobs = this.blobs;
    final PhotoStorage? storage = photoStorage;
    if (blobs == null || storage == null) {
      return const <String, String>{};
    }
    final Map<String, String> paths = <String, String>{};
    for (final RemotePhoto photo in photos) {
      if (photo.deletedAt != null) {
        continue;
      }
      try {
        paths[photo.id] = await storage.writeBytes(
          await blobs.download(photo.storagePath),
        );
      } catch (error, stackTrace) {
        debugPrint('Downloading photo ${photo.id} failed: $error');
        if (kDebugMode) {
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }
    return paths;
  }

  /// Removes the local files behind [photos], skipping any that never had
  /// one (a photo whose binary could not be downloaded).
  Future<void> deleteFiles(List<Photo> photos) async {
    final PhotoStorage? storage = photoStorage;
    if (storage == null) {
      return;
    }
    for (final Photo photo in photos) {
      if (photo.path.isNotEmpty) {
        await storage.delete(photo.path);
      }
    }
  }
}
