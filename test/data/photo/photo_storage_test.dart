import 'dart:io';
import 'dart:typed_data';

import 'package:eatapp/data/photo/photo_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The real photo store, on temp directories instead of the app's support and
/// cache directories — the part of `FilePhotoStorage` that has no platform
/// channel in it. The picker has already bounded a photo by the time it gets
/// here, so the store's job is to keep the bytes exactly as they are and to
/// clean up after the picker; a slip in either loses or leaks a user's photo
/// without ever throwing.
void main() {
  late Directory root;
  late Directory temp;
  late FilePhotoStorage storage;

  setUp(() {
    root = Directory.systemTemp.createTempSync('eatapp-photo-test');
    temp = Directory.systemTemp.createTempSync('eatapp-photo-cache');
    storage = FilePhotoStorage(supportDirectory: root, temporaryDirectory: temp);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    temp.deleteSync(recursive: true);
  });

  /// Stands in for a photo: the store never decodes it, so any bytes will do.
  Uint8List photoBytes() => Uint8List.fromList(<int>[0xFF, 0xD8, 1, 2, 3, 4]);

  /// Writes [bytes] outside the cache (an import, a fixture) and returns the
  /// path.
  Future<String> picked(Uint8List bytes, {String name = 'picked.jpg'}) async {
    final File file = File(p.join(root.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  test('stores the photo byte for byte under a photos/ directory', () async {
    final Uint8List bytes = photoBytes();

    final String stored = await storage.persist(await picked(bytes));

    expect(p.basename(p.dirname(stored)), 'photos');
    expect(p.extension(stored), '.jpg');
    expect(File(stored).readAsBytesSync(), bytes);
  });

  test('keeps the source extension, so a HEIC stays a HEIC', () async {
    final String stored = await storage.persist(
      await picked(photoBytes(), name: 'IMG_0001.HEIC'),
    );

    expect(p.extension(stored), '.heic');
  });

  test('gives an extensionless source a .jpg name', () async {
    final String stored = await storage.persist(
      await picked(photoBytes(), name: 'picked'),
    );

    expect(p.extension(stored), '.jpg');
  });

  test('each stored copy gets its own name', () async {
    final String source = await picked(photoBytes());

    final String first = await storage.persist(source);
    final String second = await storage.persist(source);

    expect(first, isNot(second));
  });

  test('delete removes the file and tolerates one that is already gone', () async {
    final String stored = await storage.persist(await picked(photoBytes()));

    await storage.delete(stored);
    expect(File(stored).existsSync(), isFalse);

    // A row whose file is already gone must still delete cleanly.
    await storage.delete(stored);
  });

  group('picker temp files', () {
    Future<File> inCache(String name, {Duration age = Duration.zero}) async {
      final File file = File(p.join(temp.path, name));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(photoBytes(), flush: true);
      await file.setLastModified(DateTime.now().subtract(age));
      return file;
    }

    test('persisting a picked file removes it from the cache', () async {
      final File source = await inCache('image_picker_1.png');

      final String stored = await storage.persist(source.path);

      expect(File(stored).existsSync(), isTrue);
      expect(source.existsSync(), isFalse);
    });

    test('a source outside the cache is never deleted', () async {
      final String source = await picked(photoBytes());

      await storage.persist(source);

      expect(File(source).existsSync(), isTrue);
    });

    test('the sweep removes only stale picked images', () async {
      final File stale = await inCache(
        'nested/old.jpg',
        age: const Duration(days: 3),
      );
      final File fresh = await inCache('new.jpg');
      final File other = await inCache(
        'share_plus/export.eatapp',
        age: const Duration(days: 3),
      );

      final int deleted = await storage.sweepPickerLeftovers();

      expect(deleted, 1);
      expect(stale.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue, reason: 'it may be on screen');
      expect(other.existsSync(), isTrue, reason: 'not a picked image');
    });
  });
}
