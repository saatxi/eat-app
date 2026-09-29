import 'package:eatapp/data/sync/photo_blob_store.dart';

/// A hand-written [PhotoBlobStore] backed by an in-memory map, so the engine's
/// photo upload/download can be exercised with no network.
class FakePhotoBlobStore implements PhotoBlobStore {
  /// The stored objects, keyed by path.
  final Map<String, List<int>> objects = <String, List<int>>{};

  /// Every path uploaded, in order, for asserting the binary goes before its
  /// row.
  final List<String> uploadLog = <String>[];

  /// When set, [download] throws for this exact path — to model a binary that
  /// is missing or that the caller may not read.
  String? failingDownloadPath;

  @override
  Future<void> upload(String path, List<int> bytes) async {
    uploadLog.add(path);
    objects[path] = bytes;
  }

  @override
  Future<List<int>> download(String path) async {
    if (path == failingDownloadPath) {
      throw StateError('no object at $path');
    }
    return objects[path] ?? const <int>[];
  }

  @override
  Future<void> delete(String path) async {
    objects.remove(path);
  }
}
