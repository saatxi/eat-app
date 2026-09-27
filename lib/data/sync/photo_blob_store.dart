import 'dart:typed_data';

import 'package:supabase/supabase.dart';

/// The remote object store the photo *binaries* live in — the counterpart of
/// [SyncTransport], which carries only rows.
///
/// Tests supply a hand-written fake, the same pattern as the transport and the
/// identity gateway, so the engine can be exercised with no network.
abstract class PhotoBlobStore {
  /// Uploads [bytes] to [path], replacing any object already there.
  Future<void> upload(String path, List<int> bytes);

  /// Downloads the object at [path].
  Future<List<int>> download(String path);

  /// Removes the object at [path]. A path with no object is not an error.
  Future<void> delete(String path);
}

/// The real [PhotoBlobStore], over Supabase Storage's private `photos` bucket.
///
/// The path convention (`{group_id}/{photo_id}`) matches the bucket's own
/// access rule, which scopes objects to groups the caller belongs to.
class SupabasePhotoBlobStore implements PhotoBlobStore {
  SupabasePhotoBlobStore(this._client);

  final SupabaseClient _client;

  static const String _bucket = 'photos';

  @override
  Future<void> upload(String path, List<int> bytes) async {
    await _client.storage
        .from(_bucket)
        .uploadBinary(path, Uint8List.fromList(bytes));
  }

  @override
  Future<List<int>> download(String path) =>
      _client.storage.from(_bucket).download(path);

  @override
  Future<void> delete(String path) async {
    await _client.storage.from(_bucket).remove(<String>[path]);
  }
}
