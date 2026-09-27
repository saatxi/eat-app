import 'dart:io';

import 'package:drift/native.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The 16→17 migration: the two drift-only tables the sync layer keeps —
/// `pending_syncs` (the push queue) and `sync_cursors` (the pull cursor).
/// The migration is purely additive, so a v16 install keeps every row it had.
///
/// The v16 file is built with raw sqlite3 (no drift involved, exactly what a
/// real v16 install has on disk) and then opened by [AppDatabase], whose
/// migration runs 16→17 on open.
void main() {
  test('16→17 creates the sync tables and keeps existing rows', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp('eatapp');
    final String dbPath = '${tempDir.path}/v16.db';
    addTearDown(() => tempDir.delete(recursive: true));

    // Build the v16 file by hand — the schema exactly as v16 wrote it: the
    // v15 tables plus the four additive sync columns on each shared table.
    final sqlite3.Database raw = sqlite3.sqlite3.open(dbPath);
    raw.execute('''
      CREATE TABLE restaurants (
        groupId TEXT,
        createdBy TEXT,
        updatedAt INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER,
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        "cuisineType" TEXT NOT NULL,
        address TEXT,
        "priceRange" INTEGER NOT NULL,
        website TEXT,
        instagram TEXT,
        city TEXT,
        region TEXT,
        country TEXT,
        searchText TEXT NOT NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE visits (
        groupId TEXT,
        createdBy TEXT,
        updatedAt INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER,
        id TEXT NOT NULL PRIMARY KEY,
        restaurantId TEXT NOT NULL REFERENCES restaurants (id) ON DELETE CASCADE,
        visitDate INTEGER NOT NULL,
        rating INTEGER NOT NULL,
        notes TEXT,
        "priceRange" INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE photos (
        groupId TEXT,
        createdBy TEXT,
        updatedAt INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER,
        id TEXT NOT NULL PRIMARY KEY,
        restaurantId TEXT REFERENCES restaurants (id) ON DELETE CASCADE,
        visitId TEXT REFERENCES visits (id) ON DELETE CASCADE,
        path TEXT NOT NULL,
        position INTEGER NOT NULL
      );
    ''');
    raw.execute(
      "INSERT INTO restaurants (groupId, createdBy, updatedAt, deletedAt, id, "
      "name, \"cuisineType\", address, \"priceRange\", website, instagram, city, "
      "region, country, searchText) VALUES (NULL, NULL, 0, NULL, 'r1', "
      "'Old place', 'italian', NULL, 2, NULL, NULL, 'Rome', NULL, 'Italy', "
      "'old place italian rome italy')",
    );
    raw.execute('PRAGMA user_version = 16');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(File(dbPath)));

    // The existing rows survive, still private.
    final restaurants = await upgraded.select(upgraded.restaurants).get();
    expect(restaurants.single.id, 'r1');
    expect(restaurants.single.groupId, isNull);

    // The two new tables exist and start empty.
    expect(await upgraded.select(upgraded.pendingSyncs).get(), isEmpty);
    expect(await upgraded.select(upgraded.syncCursors).get(), isEmpty);

    // And they are writable with the expected columns.
    await upgraded.into(upgraded.pendingSyncs).insert(
      PendingSyncsCompanion.insert(
        sharedTable: 'restaurants',
        rowId: 'r1',
        groupId: 'g1',
      ),
    );
    final PendingSync queued =
        (await upgraded.select(upgraded.pendingSyncs).get()).single;
    expect(queued.sharedTable, 'restaurants');
    expect(queued.rowId, 'r1');
    expect(queued.groupId, 'g1');

    await upgraded.close();
  });
}
