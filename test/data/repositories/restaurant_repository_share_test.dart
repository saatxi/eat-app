import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/share/backup_writer.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// Records every snapshot the repository hands it, instead of touching disk.
class _RecordingBackupWriter implements BackupWriter {
  final List<List<RestaurantExport>> writes = <List<RestaurantExport>>[];

  @override
  Future<void> write(List<RestaurantExport> restaurants) async {
    writes.add(restaurants);
  }
}

void main() {
  late AppDatabase db;
  late RestaurantRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
  });

  tearDown(() => db.close());

  group('exportRestaurants', () {
    test('carries each restaurant\'s tags and visits', () async {
      await repository.insert(
        restaurant(id: 'a', name: 'Cal Ferran', cuisineType: 'mediterranean'),
        tags: const <String>['Terraza'],
      );
      await repository.addVisit(
        restaurantId: 'a',
        visitDate: 1000,
        rating: 4,
        notes: 'bona',
      );

      final List<RestaurantExport> exports = await repository.exportRestaurants();

      expect(exports, hasLength(1));
      expect(exports.single.name, 'Cal Ferran');
      expect(exports.single.tags, <String>['Terraza']);
      expect(exports.single.visits.single.rating, 4);
    });

    test('leaves visits out when asked to', () async {
      await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
      await repository.addVisit(
        restaurantId: 'a',
        visitDate: 1000,
        rating: 4,
      );

      final List<RestaurantExport> exports = await repository.exportRestaurants(
        includeVisits: false,
      );

      expect(exports.single.visits, isEmpty);
    });

    test('limits the export to the given ids', () async {
      await repository.insert(restaurant(id: 'a', name: 'First'));
      await repository.insert(restaurant(id: 'b', name: 'Second'));

      final List<RestaurantExport> exports = await repository.exportRestaurants(
        restaurantIds: <String>['b'],
      );

      expect(<String>[for (final RestaurantExport e in exports) e.name], <String>['Second']);
    });
  });

  group('the backup snapshot', () {
    test('is written after an insert, a delete and a visit', () async {
      final _RecordingBackupWriter writer = _RecordingBackupWriter();
      final RestaurantRepository backedUp = RestaurantRepository(
        db,
        backupWriter: writer,
      );

      await backedUp.insert(restaurant(id: 'a', name: 'Cal Ferran'));
      await backedUp.addVisit(restaurantId: 'a', visitDate: 1000, rating: 4);
      await backedUp.delete('a');

      expect(writer.writes, hasLength(3));
      expect(writer.writes[0].single.name, 'Cal Ferran');
      expect(writer.writes[1].single.visits, hasLength(1));
      // The last snapshot reflects the delete.
      expect(writer.writes[2], isEmpty);
    });

    test('is skipped entirely when no writer was supplied', () async {
      // Nothing to assert beyond "does not throw" — the bare repository from
      // setUp has no writer, and every mutation should stay a no-op on files.
      await repository.insert(restaurant(id: 'a', name: 'Cal Ferran'));
      await repository.delete('a');
    });
  });
}
