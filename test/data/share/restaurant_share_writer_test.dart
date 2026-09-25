import 'dart:io';

import 'package:eatapp/data/share/restaurant_import_reader.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:eatapp/data/share/restaurant_share_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('eatapp_share_writer_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('shareFileName', () {
    test('names a bulk export generically and a single one after itself', () {
      final DateTime now = DateTime(2026, 9, 13, 17, 42);
      expect(shareFileName(now: now), 'restaurants-20260913_1742.eatapp');
      expect(
        shareFileName(singleName: 'Cal Ferran', now: now),
        'cal-ferran-20260913_1742.eatapp',
      );
    });
  });

  group('writeRestaurantShareFile', () {
    test('writes the file under a shared/ subdirectory of the given directory', () async {
      final File file = await writeRestaurantShareFile(
        directory: tempDir,
        restaurants: <RestaurantExport>[
          const RestaurantExport(name: 'A', cuisineType: 'italian', priceRange: 1),
        ],
        now: DateTime(2026, 9, 13, 17, 42),
      );

      expect(p.dirname(file.path), p.join(tempDir.path, shareSubdir));
      expect(p.basename(file.path), 'restaurants-20260913_1742.eatapp');
      expect(file.existsSync(), isTrue);

      final ImportOutcome outcome = readRestaurantImport(await file.readAsString());
      expect((outcome as ImportSuccess).restaurants.single.restaurant.name, 'A');
    });

    test('deletes the previous share so the directory never accumulates', () async {
      await writeRestaurantShareFile(
        directory: tempDir,
        restaurants: <RestaurantExport>[
          const RestaurantExport(name: 'First', cuisineType: 'italian', priceRange: 1),
        ],
        now: DateTime(2026, 9, 13, 17, 42),
      );
      final File second = await writeRestaurantShareFile(
        directory: tempDir,
        restaurants: <RestaurantExport>[
          const RestaurantExport(name: 'Second', cuisineType: 'italian', priceRange: 1),
        ],
        now: DateTime(2026, 9, 13, 17, 43),
      );

      final List<File> files = Directory(p.join(tempDir.path, shareSubdir))
          .listSync()
          .whereType<File>()
          .toList();
      expect(files, hasLength(1));
      expect(files.single.path, second.path);
    });
  });

  group('writeBackupFile', () {
    test('writes backup.json next to the data, not under shared/', () async {
      final File file = await writeBackupFile(
        directory: tempDir,
        restaurants: <RestaurantExport>[
          const RestaurantExport(name: 'A', cuisineType: 'italian', priceRange: 1),
        ],
      );

      expect(file.path, p.join(tempDir.path, backupFileName));
      expect(file.existsSync(), isTrue);
    });
  });
}
