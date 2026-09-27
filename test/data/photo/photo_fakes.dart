import 'package:eatapp/data/photo/photo_picker.dart';
import 'package:eatapp/data/photo/photo_storage.dart';

/// A [PhotoPicker] that hands back [nextPath] every time (or null to model the
/// user backing out), counting the calls so a test can assert the picker was
/// reached.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.nextPath});

  /// The path the next pick returns; null means "cancelled".
  String? nextPath;

  int pickCount = 0;

  @override
  Future<String?> pickFromGallery() async {
    pickCount++;
    return nextPath;
  }
}

/// A [PhotoStorage] that never touches the disk: it maps every source into a
/// `stored/` prefix and records the paths a caller asked to delete, so a test
/// can assert the file lifecycle without a real file system.
///
/// Bytes are kept in [files], so a sync test can seed what [readBytes] returns
/// and inspect what [writeBytes] wrote.
class FakePhotoStorage implements PhotoStorage {
  final List<String> deleted = <String>[];
  int persistCount = 0;

  /// What [readBytes] returns, keyed by path.
  final Map<String, List<int>> files = <String, List<int>>{};

  /// What [writeBytes] wrote, keyed by the path it returned.
  final Map<String, List<int>> written = <String, List<int>>{};

  int _written = 0;

  @override
  Future<void> delete(String storedPath) async => deleted.add(storedPath);

  @override
  Future<String> persist(String sourcePath) async {
    persistCount++;
    return 'stored/${sourcePath.split('/').last}';
  }

  @override
  Future<List<int>> readBytes(String storedPath) async =>
      files[storedPath] ?? const <int>[];

  @override
  Future<String> writeBytes(List<int> bytes) async {
    final String path = 'stored/downloaded-${_written++}';
    written[path] = bytes;
    return path;
  }
}
