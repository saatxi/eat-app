import '../db/app_database.dart';
import '../photo/photo_storage.dart';
import 'pending_sync_store.dart';
import 'photo_blob_store.dart';
import 'photo_blob_sync.dart';
import 'sync_cursor_store.dart';
import 'sync_puller.dart';
import 'sync_pusher.dart';
import 'sync_transport.dart';

/// Orchestrates the two halves of the sync layer: pushing the pending queue
/// out ([SyncPusher]), and pulling remote changes in ([SyncPuller]). Both
/// share one [PhotoBlobSync] for the binaries behind a photo row.
///
/// A screen or a scheduler drives [syncGroup]; the [SyncTransport] is the only
/// piece that knows the remote exists.
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required PendingSyncStore pending,
    required SyncCursorStore cursors,
    required SyncTransport transport,
    this.photoStorage,
    this.blobs,
  }) {
    final PhotoBlobSync photoBlobs = PhotoBlobSync(
      photoStorage: photoStorage,
      blobs: blobs,
    );
    _pusher = SyncPusher(database, pending, transport, photoBlobs);
    _puller = SyncPuller(database, cursors, transport, photoBlobs);
  }

  /// The local photo store and the remote blob store, both needed together for
  /// photos to sync at all. Null (a unit test, a build with no backend) simply
  /// skips photo binaries — rows still sync.
  final PhotoStorage? photoStorage;
  final PhotoBlobStore? blobs;

  late final SyncPusher _pusher;
  late final SyncPuller _puller;

  /// Pushes this device's changes, then pulls the group's — push first so the
  /// remote has our rows before we ask what changed since we last looked.
  ///
  /// A push that fails does not cost us the pull: what the rest of the group
  /// changed is independent of whether our own queue could be sent, and a row
  /// the server keeps refusing would otherwise freeze every future pull behind
  /// it — the very rows we came for would never arrive. The push failure is
  /// remembered and rethrown once the pull has had its chance, so the caller
  /// still learns about it.
  Future<void> syncGroup(String groupId) async {
    Object? pushError;
    StackTrace? pushStack;
    try {
      await pushGroup(groupId);
    } catch (error, stackTrace) {
      pushError = error;
      pushStack = stackTrace;
    }

    await pullGroup(groupId);

    if (pushError != null) {
      Error.throwWithStackTrace(pushError, pushStack!);
    }
  }

  Future<void> pushGroup(String groupId) => _pusher.pushGroup(groupId);

  Future<void> pullGroup(String groupId) => _puller.pullGroup(groupId);
}
