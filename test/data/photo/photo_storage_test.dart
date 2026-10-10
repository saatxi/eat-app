import 'dart:io';
import 'dart:typed_data';

import 'package:eatapp/data/photo/photo_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// The real photo pipeline, on a temp directory instead of the app's support
/// directory — the one part of `FilePhotoStorage` that has no platform channel
/// in it. Worth holding down because it fails silently: a wrong bound or a
/// dropped fallback corrupts a user's photo without ever throwing.
void main() {
  late Directory root;
  late Directory temp;
  late FilePhotoStorage storage;

  /// Small enough that a handful of pixels exercises the bounding path.
  const int bound = 64;

  setUp(() {
    root = Directory.systemTemp.createTempSync('eatapp-photo-test');
    temp = Directory.systemTemp.createTempSync('eatapp-photo-cache');
    storage = FilePhotoStorage(
      supportDirectory: root,
      temporaryDirectory: temp,
      maxDimension: bound,
    );
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    temp.deleteSync(recursive: true);
  });

  /// Writes [bytes] where a picker would have left them and returns that path.
  Future<String> picked(Uint8List bytes, {String name = 'picked.png'}) async {
    final File file = File(p.join(root.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  img.Image storedImage(String storedPath) =>
      img.decodeImage(File(storedPath).readAsBytesSync())!;

  test('stores a JPEG under a photos/ directory beside the database', () async {
    final String stored = await storage.persist(
      await picked(Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)))),
    );

    expect(p.extension(stored), '.jpg');
    expect(p.basename(p.dirname(stored)), 'photos');
    expect(File(stored).existsSync(), isTrue);
  });

  test('bounds a landscape photo by its width, keeping the ratio', () async {
    final String stored = await storage.persist(
      await picked(Uint8List.fromList(img.encodePng(img.Image(width: 200, height: 100)))),
    );

    final img.Image decoded = storedImage(stored);
    expect(decoded.width, bound);
    expect(decoded.height, bound ~/ 2);
  });

  test('bounds a portrait photo by its height, keeping the ratio', () async {
    final String stored = await storage.persist(
      await picked(Uint8List.fromList(img.encodePng(img.Image(width: 100, height: 300)))),
    );

    final img.Image decoded = storedImage(stored);
    expect(decoded.height, bound);
    expect(decoded.width, closeTo(21, 1));
  });

  test('leaves an image already inside the bound at its own size', () async {
    final String stored = await storage.persist(
      await picked(Uint8List.fromList(img.encodePng(img.Image(width: 20, height: 10)))),
    );

    final img.Image decoded = storedImage(stored);
    expect(decoded.width, 20);
    expect(decoded.height, 10);
  });

  test('keeps bytes it cannot decode rather than losing the photo', () async {
    final Uint8List notAnImage = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    final String stored = await storage.persist(
      await picked(notAnImage, name: 'mystery.heic'),
    );

    // Stored verbatim, under its own extension: an unreadable format is still
    // the user's photo.
    expect(p.extension(stored), '.heic');
    expect(File(stored).readAsBytesSync(), notAnImage);
  });

  test('delete removes the file and tolerates one that is already gone', () async {
    final String stored = await storage.persist(
      await picked(Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)))),
    );

    await storage.delete(stored);
    expect(File(stored).existsSync(), isFalse);

    // A row whose file is already gone must still delete cleanly.
    await storage.delete(stored);
  });

  group('picker temp files', () {
    Uint8List png() =>
        Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));

    Future<File> inCache(String name, {Duration age = Duration.zero}) async {
      final File file = File(p.join(temp.path, name));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png(), flush: true);
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
      final String source = await picked(png());

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
