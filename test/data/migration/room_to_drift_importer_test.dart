import 'dart:io';

import 'package:drift/native.dart';
import 'package:eatapp/core/utils/search_normalizer.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/migration/room_to_drift_importer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/db_test_utils.dart';

/// Hands back whatever file the test built, or nothing at all.
class _StubLocator implements RoomDatabaseLocator {
  const _StubLocator(this.file);

  final File? file;

  @override
  Future<File?> locate() async => file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late SharedPreferences preferences;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('eatapp_import_test');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  /// Builds a file that stands in for the one Room leaves behind: the same five
  /// tables with the same columns, plus Room's own bookkeeping table.
  ///
  /// It is written with drift rather than by hand, which is possible precisely
  /// because the two schemas were mirrored 1:1 — and it is the column *names*
  /// the import relies on, never the order they were declared in.
  Future<File> createLegacyDatabase({
    Future<void> Function(AppDatabase legacy)? populate,
    bool withRoomMasterTable = true,
  }) async {
    final File file = File(p.join(tempDirectory.path, 'eatapp.db'));
    final AppDatabase legacy = AppDatabase(NativeDatabase(file));
    // drift creates the file lazily, so this has to run before anything else —
    // otherwise a legacy database with no rows never becomes a file at all.
    await legacy.customSelect('SELECT 1').get();
    if (populate != null) {
      await populate(legacy);
    }
    if (withRoomMasterTable) {
      await legacy.customStatement(
        'CREATE TABLE room_master_table (id INTEGER PRIMARY KEY, identity_hash TEXT)',
      );
      await legacy.customStatement(
        "INSERT INTO room_master_table (id, identity_hash) VALUES (42, 'eatapp')",
      );
    }
    await legacy.close();
    return file;
  }

  RoomToDriftImporter importerFor(
    AppDatabase target, {
    required File? legacy,
  }) => RoomToDriftImporter(
    database: target,
    locator: _StubLocator(legacy),
    preferences: preferences,
  );

  test('a fresh install with no Room file imports nothing and stays unmarked', () async {
    final AppDatabase target = AppDatabase.memory();
    addTearDown(target.close);

    final RoomImportResult result = await importerFor(
      target,
      legacy: null,
    ).run();

    expect(result.outcome, RoomImportOutcome.nothingToImport);
    expect(
      preferences.getBool('data_migration.room_to_drift.done'),
      isNull,
      reason: 'a Room file appearing later must still be imported',
    );
  });

  test('a file that is not a SQLite database at all is a quiet no-op', () async {
    final File notADatabase = File(p.join(tempDirectory.path, 'eatapp.db'));
    await notADatabase.writeAsString('this is not a database');
    final AppDatabase target = AppDatabase.memory();
    addTearDown(target.close);

    final RoomImportResult result = await importerFor(
      target,
      legacy: notADatabase,
    ).run();

    expect(result.outcome, RoomImportOutcome.nothingToImport);
    expect(File('${notADatabase.path}.bak').existsSync(), isFalse);
  });

  test('a SQLite file that Room never wrote is a no-op', () async {
    final File foreign = await createLegacyDatabase(
      withRoomMasterTable: false,
    );
    final AppDatabase target = AppDatabase.memory();
    addTearDown(target.close);

    final RoomImportResult result = await importerFor(
      target,
      legacy: foreign,
    ).run();

    expect(result.outcome, RoomImportOutcome.nothingToImport);
    expect(
      File('${foreign.path}.bak').existsSync(),
      isFalse,
      reason: 'nothing is copied, so nothing needs backing up',
    );
  });

  test('copies every table, keeping the ids and the derived search text', () async {
    final File legacy = await createLegacyDatabase(
      populate: (AppDatabase db) async {
        await db.restaurantDao.insertRestaurant(
          restaurant(
            id: 'r1',
            name: 'Mediterránea',
            cuisineType: 'italian',
            city: 'Barcelona',
          ),
        );
        await db.restaurantDao.insertRestaurant(
          restaurant(id: 'r2', name: 'Thai Place', cuisineType: 'thai'),
        );
        await db.tagDao.setTags('r1', <String>['Terraza', 'Coeliac']);
        await db.visitDao.insertVisit(
          visit(id: 'v1', restaurantId: 'r1', visitDate: 1000, rating: 5),
        );
        await db.visitDao.insertVisit(
          visit(id: 'v2', restaurantId: 'r2', visitDate: 2000, rating: 3),
        );
        await db.photoDao.insertPhoto(
          photo(id: 'p1', restaurantId: 'r1', path: '/photos/p1.jpg'),
        );
        await db.photoDao.insertPhoto(
          photo(id: 'p2', visitId: 'v1', path: '/photos/p2.jpg'),
        );
      },
    );
    final AppDatabase target = AppDatabase.memory();
    addTearDown(target.close);

    final RoomImportResult result = await importerFor(
      target,
      legacy: legacy,
    ).run();

    expect(result.outcome, RoomImportOutcome.imported);
    expect(result.isComplete, isTrue);
    expect(
      <int>[for (final t in result.tables.values) t.available],
      everyElement(greaterThan(0)),
      reason: 'every table had rows to move',
    );

    final Restaurant mediterranean = (await target.restaurantDao
        .observeById('r1')
        .first)!;
    expect(mediterranean.name, 'Mediterránea');
    expect(
      mediterranean.searchText,
      buildSearchText(
        name: 'Mediterránea',
        cuisineType: 'italian',
        city: 'Barcelona',
      ),
    );

    expect(
      await target.tagDao.observeTagNames('r1').first,
      <String>['Coeliac', 'Terraza'],
    );
    expect(
      await target.visitDao.observeVisitsForRestaurant('r1').first,
      hasLength(1),
    );
    expect(
      await target.photoDao.observePhotosForRestaurant('r1').first,
      hasLength(1),
    );
    expect(
      await target.photoDao.observePhotosForVisit('v1').first,
      hasLength(1),
    );
    expect(await target.restaurantDao.observeTotalCount().first, 2);
  });

  test('takes a copy of the legacy file and leaves the original alone', () async {
    final File legacy = await createLegacyDatabase(
      populate: (AppDatabase db) async {
        await db.restaurantDao.insertRestaurant(
          restaurant(id: 'r1', name: 'First'),
        );
      },
    );
    final int sizeBefore = legacy.lengthSync();
    final AppDatabase target = AppDatabase.memory();
    addTearDown(target.close);

    await importerFor(target, legacy: legacy).run();

    final File backup = File('${legacy.path}.bak');
    expect(backup.existsSync(), isTrue);
    expect(backup.lengthSync(), sizeBefore);
    expect(
      legacy.lengthSync(),
      sizeBefore,
      reason: 'the import only ever reads the Room file',
    );
  });

  test('a second run reports that it is already done, without copying again', () async {
    final File legacy = await createLegacyDatabase(
      populate: (AppDatabase db) async {
        await db.restaurantDao.insertRestaurant(
          restaurant(id: 'r1', name: 'First'),
        );
      },
    );
    final AppDatabase target = AppDatabase.memory();
    addTearDown(target.close);
    final RoomToDriftImporter importer = importerFor(target, legacy: legacy);

    expect((await importer.run()).outcome, RoomImportOutcome.imported);
    expect(importer.isDone, isTrue);

    final RoomImportResult second = await importer.run();

    expect(second.outcome, RoomImportOutcome.alreadyImported);
    expect(second.tables, isEmpty);
    expect(
      await target.restaurantDao.observeTotalCount().first,
      1,
      reason: 'the flag is what stops the rows from arriving twice',
    );
  });

  test('a fresh database with the flag already set is left alone', () async {
    final File legacy = await createLegacyDatabase(
      populate: (AppDatabase db) async {
        await db.restaurantDao.insertRestaurant(
          restaurant(id: 'r1', name: 'First'),
        );
      },
    );
    await preferences.setBool('data_migration.room_to_drift.done', true);
    final AppDatabase target = AppDatabase.memory();
    addTearDown(target.close);

    final RoomImportResult result = await importerFor(
      target,
      legacy: legacy,
    ).run();

    expect(result.outcome, RoomImportOutcome.alreadyImported);
    expect(await target.restaurantDao.observeTotalCount().first, 0);
  });

  test('a row that already exists keeps the local value', () async {
    final File legacy = await createLegacyDatabase(
      populate: (AppDatabase db) async {
        await db.restaurantDao.insertRestaurant(
          restaurant(id: 'r1', name: 'From the old app'),
        );
      },
    );
    final AppDatabase target = AppDatabase.memory();
    addTearDown(target.close);
    await target.restaurantDao.insertRestaurant(
      restaurant(id: 'r1', name: 'Already here'),
    );

    final RoomImportResult result = await importerFor(
      target,
      legacy: legacy,
    ).run();

    expect(result.outcome, RoomImportOutcome.imported);
    expect(
      (await target.restaurantDao.observeById('r1').first)!.name,
      'Already here',
      reason: 'the copy is `OR IGNORE`, so it can never overwrite a row',
    );
    expect(await target.restaurantDao.observeTotalCount().first, 1);
  });
}
