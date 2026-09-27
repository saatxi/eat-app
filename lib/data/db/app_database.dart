import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/photo_dao.dart';
import 'daos/restaurant_dao.dart';
import 'daos/visit_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app's SQLite database, carried over from the Android app's Room schema.
///
/// [schemaVersion] began at 14 — Room's frozen baseline — so the Room→drift
/// import could adopt an existing install's file without a version bump. It is
/// now 17: 15 dropped the removed tag feature's two tables, 16 added the
/// shared-group sync metadata (`groupId`, `createdBy`, `updatedAt`,
/// `deletedAt`) to every shared table, and 17 added the two drift-only tables
/// the sync layer itself keeps — [PendingSyncs] (the push queue) and
/// [SyncCursors] (the per-group pull cursor). Every migration so far is purely
/// additive, so existing rows stay private (`groupId` NULL) without backfill.
@DriftDatabase(
  tables: <Type>[Restaurants, Visits, Photos, PendingSyncs, SyncCursors],
  daos: <Type>[RestaurantDao, VisitDao, PhotoDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// An in-memory database, for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 17;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      // 14 -> 15: the tag feature is gone, so its two tables go with it.
      // Dropping them discards any rows a user had entered — deliberately,
      // since nothing in the app reads them any more.
      if (from < 15) {
        await customStatement('DROP TABLE IF EXISTS restaurant_tags');
        await customStatement('DROP TABLE IF EXISTS tags');
      }
      // 15 -> 16: shared-group sync metadata, additive only. Every existing
      // row keeps groupId NULL (private) and gets updatedAt 0, which the sync
      // layer treats as "never written since the upgrade" — the first real
      // write stamps it properly.
      if (from < 16) {
        await m.addColumn(restaurants, restaurants.groupId);
        await m.addColumn(restaurants, restaurants.createdBy);
        await m.addColumn(restaurants, restaurants.updatedAt);
        await m.addColumn(restaurants, restaurants.deletedAt);
        await m.addColumn(visits, visits.groupId);
        await m.addColumn(visits, visits.createdBy);
        await m.addColumn(visits, visits.updatedAt);
        await m.addColumn(visits, visits.deletedAt);
        await m.addColumn(photos, photos.groupId);
        await m.addColumn(photos, photos.createdBy);
        await m.addColumn(photos, photos.updatedAt);
        await m.addColumn(photos, photos.deletedAt);
      }
      // 16 -> 17: the sync layer's own bookkeeping — the push queue and the
      // per-group pull cursor. Both are drift-only tables with no Room
      // counterpart, so creating them is the whole migration.
      if (from < 17) {
        await m.createTable(pendingSyncs);
        await m.createTable(syncCursors);
      }
    },
    // SQLite requires this per connection, and every cascade delete the schema
    // declares (visits, photos) only fires with foreign keys on.
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Opens the app's database file.
///
/// This is deliberately *not* Room's file. Room's database lives in the private
/// `databases/` directory, and this one is a drift-owned file in the app's
/// support directory that the Room→drift import fills in from it once, on first
/// launch. Leaving the original untouched is what makes the import safe to
/// attempt: a failure part-way through has a `.bak` next to it and a flag that
/// was never set, so the next launch simply tries again.
QueryExecutor openAppDatabase() => driftDatabase(
  name: 'eatapp',
  native: DriftNativeOptions(
    databasePath: () async {
      final Directory supportDirectory = await getApplicationSupportDirectory();
      return p.join(supportDirectory.path, 'eatapp.db');
    },
  ),
);
