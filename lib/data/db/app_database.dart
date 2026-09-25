import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/photo_dao.dart';
import 'daos/restaurant_dao.dart';
import 'daos/tag_dao.dart';
import 'daos/visit_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app's SQLite database, carried over from the Android app's Room schema.
///
/// [schemaVersion] is 14 — Room's frozen baseline — so that the Room→drift
/// import can adopt an existing install's file without a version bump. Every
/// future bump must ship a real drift migration; see [migration].
@DriftDatabase(
  tables: <Type>[Restaurants, Tags, RestaurantTags, Visits, Photos],
  daos: <Type>[RestaurantDao, TagDao, VisitDao, PhotoDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// An in-memory database, for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    // Version 14 is the frozen baseline Room left behind, so there is nothing
    // to migrate *from* yet: a bump that reaches this callback is a bug, and
    // failing loudly is much better than silently leaving the user's rows
    // behind a schema their app no longer understands.
    onUpgrade: (Migrator m, int from, int to) => throw UnsupportedError(
      'No drift migration from schema $from to $to. Add one to '
      'AppDatabase.migration before bumping schemaVersion past 14.',
    ),
    // SQLite requires this per connection, and every cascade delete the schema
    // declares (tags, visits, photos) only fires with foreign keys on.
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Opens the app's database file.
///
/// The file is named `eatapp.db` after Room's own, so the Room→drift import
/// (next block) can point this at the very file an existing Android install
/// already has and keep its rows. Until that import exists, this is simply a
/// fresh drift-owned file in the app's support directory.
QueryExecutor openAppDatabase() => driftDatabase(
  name: 'eatapp',
  native: DriftNativeOptions(
    databasePath: () async {
      final Directory supportDirectory = await getApplicationSupportDirectory();
      return p.join(supportDirectory.path, 'eatapp.db');
    },
  ),
);
