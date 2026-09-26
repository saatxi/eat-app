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
class FakePhotoStorage implements PhotoStorage {
  final List<String> deleted = <String>[];
  int persistCount = 0;

  @override
  Future<void> delete(String storedPath) async => deleted.add(storedPath);

  @override
  Future<String> persist(String sourcePath) async {
    persistCount++;
    return 'stored/${sourcePath.split('/').last}';
  }
}
