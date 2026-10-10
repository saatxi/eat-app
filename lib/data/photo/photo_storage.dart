import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// The app's own store for restaurant and visit photos.
///
/// Photos are never referenced in place: whatever the system picker hands back
/// is a temporary file that the OS may clean up at any moment, so the app keeps
/// its own copy under its private directory (the counterpart of the Android
/// app's `RestaurantPhotoStorage`). The interface exists so the screens and the
/// repository can be exercised against a fake with no platform channel.
abstract interface class PhotoStorage {
  /// Copies the image at [sourcePath] into the app's private photo directory
  /// and returns the stored copy's absolute path. The picker has already
  /// bounded it (see `ImagePickerPhotoPicker`), so the bytes are kept as they
  /// are.
  ///
  /// The returned path is what belongs in the database; [sourcePath] is only a
  /// staging location.
  Future<String> persist(String sourcePath);

  /// Deletes the stored file at [storedPath]. A path that no longer exists (or
  /// never did) is not an error — a delete of a row whose file is already gone
  /// should still succeed.
  Future<void> delete(String storedPath);

  /// Reads the stored file's bytes, for uploading it to the remote during a
  /// sync.
  Future<List<int>> readBytes(String storedPath);

  /// Writes [bytes] as a new stored file and returns its path, for a photo the
  /// sync downloaded from the remote.
  Future<String> writeBytes(List<int> bytes);
}

/// The real [PhotoStorage]: a `photos/` directory beside the database.
///
/// It stores the picked file byte for byte. Bounding the photo is the system
/// picker's job (`ImagePickerPhotoPicker` asks it for at most 1600px), done
/// natively and far faster than the pure-Dart decode and re-encode this class
/// used to run. Orientation needs no baking either: the picker keeps the EXIF
/// orientation tag, and Flutter's decoder — the only thing that ever draws a
/// stored photo, here or on another group member's phone — applies it.
///
/// The directory is `getApplicationSupportDirectory()/photos`, which is the
/// Android `filesDir/photos` the old native app used — so the absolute paths the
/// Room→drift import copies over still resolve, and photos that predate the
/// Flutter rewrite carry over untouched.
class FilePhotoStorage implements PhotoStorage {
  const FilePhotoStorage({this.supportDirectory, this.temporaryDirectory});

  /// The directory the `photos/` folder hangs off. Null — the real case — means
  /// `getApplicationSupportDirectory()`; a test passes a temp directory, which
  /// is what lets the storage be exercised with no platform channel and no
  /// device.
  final Directory? supportDirectory;

  /// The platform's temporary directory, where the system picker leaves the
  /// file it hands back. Null — the real case — means `getTemporaryDirectory()`;
  /// a test passes its own.
  final Directory? temporaryDirectory;

  /// The image extensions the picker writes, the only files [sweepPickerLeftovers]
  /// will touch — anything else in the cache belongs to someone else.
  static const Set<String> _pickedImageExtensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.heif',
    '.webp',
    '.gif',
  };

  static const String _directoryName = 'photos';
  static const Uuid _uuid = Uuid();

  @override
  Future<String> persist(String sourcePath) async {
    final Directory directory = await _photoDirectory();
    // The source's own extension is kept so the stored file still says what it
    // is (a HEIC the picker left unconverted, say); the decoder reads the bytes
    // either way.
    final String extension = p.extension(sourcePath).toLowerCase();
    final String path = p.join(
      directory.path,
      '${_uuid.v4()}${extension.isEmpty ? '.jpg' : extension}',
    );
    await File(sourcePath).copy(path);
    await _deleteIfPickerTemp(sourcePath);
    return path;
  }

  /// Deletes picked images the picker left in the temporary directory more
  /// than [olderThan] ago, returning how many went.
  ///
  /// [persist] removes the file it copied, but a pick the user discarded
  /// without saving — and every pick made before this cleanup existed — would
  /// otherwise sit in the cache for good, which is how the app's storage kept
  /// growing with each photo. Only image files are touched, and only stale
  /// ones, so a pick still on screen in an open form is never pulled away.
  Future<int> sweepPickerLeftovers({
    Duration olderThan = const Duration(days: 1),
  }) async {
    final Directory temp = await _temporaryDirectory();
    if (!await temp.exists()) {
      return 0;
    }
    final DateTime cutoff = DateTime.now().subtract(olderThan);
    int deleted = 0;
    await for (final FileSystemEntity entity in temp.list(recursive: true)) {
      if (entity is! File ||
          !_pickedImageExtensions.contains(
            p.extension(entity.path).toLowerCase(),
          )) {
        continue;
      }
      try {
        if ((await entity.lastModified()).isBefore(cutoff)) {
          await entity.delete();
          deleted++;
        }
      } on FileSystemException {
        // Gone already, or held open by the OS: the next sweep will retry.
      }
    }
    return deleted;
  }

  /// Removes [sourcePath] once its stored copy exists, but only when it is a
  /// picker temp file — a path outside the temporary directory (an import, a
  /// test fixture) is never the app's to delete.
  ///
  /// Best-effort: the photo is already stored, so a cleanup that fails (the
  /// file already gone, or no temporary directory to resolve) must never fail
  /// the save — the next [sweepPickerLeftovers] will catch the leftover.
  Future<void> _deleteIfPickerTemp(String sourcePath) async {
    try {
      final Directory temp = await _temporaryDirectory();
      if (p.isWithin(temp.path, sourcePath)) {
        await File(sourcePath).delete();
      }
    } on Exception {
      // Nothing to reclaim, or nowhere to reclaim it from.
    }
  }

  Future<Directory> _temporaryDirectory() async =>
      temporaryDirectory ?? await getTemporaryDirectory();

  @override
  Future<void> delete(String storedPath) async {
    final File file = File(storedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<List<int>> readBytes(String storedPath) =>
      File(storedPath).readAsBytes();

  @override
  Future<String> writeBytes(List<int> bytes) async {
    final Directory directory = await _photoDirectory();
    final String path = p.join(directory.path, '${_uuid.v4()}.jpg');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<Directory> _photoDirectory() async {
    final Directory support =
        supportDirectory ?? await getApplicationSupportDirectory();
    final Directory directory = Directory(p.join(support.path, _directoryName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
