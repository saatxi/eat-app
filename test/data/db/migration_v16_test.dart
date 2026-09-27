import 'dart:io';

import 'package:drift/native.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The 15→16 migration: shared-group sync metadata added to every shared
/// table, additively. An install that already has rows must keep them all,
/// with groupId NULL (private) and updatedAt 0 ("never written since the
/// upgrade") — nothing is backfilled because there is nothing to backfill
/// from.
///
/// The v15 file is built with raw sqlite3 (no drift involved, exactly what a
/// real v15 install has on disk) and then opened by [AppDatabase], whose
/// migration runs 15→16 on open.
void main() {
  test('15→16 keeps existing rows and marks them private', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp('eatapp');
    final String dbPath = '${tempDir.path}/v15.db';
    addTearDown(() => tempDir.delete(recursive: true));

    // Build the v15 file by hand — the schema exactly as v15 wrote it.
    final sqlite3.Database raw = sqlite3.sqlite3.open(dbPath);
    raw.execute('''
      CREATE TABLE restaurants (
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
        id TEXT NOT NULL PRIMARY KEY,
        restaurantId TEXT REFERENCES restaurants (id) ON DELETE CASCADE,
        visitId TEXT REFERENCES visits (id) ON DELETE CASCADE,
        path TEXT NOT NULL,
        position INTEGER NOT NULL
      );
    ''');
    raw.execute(
      "INSERT INTO restaurants VALUES ('r1', 'Old place', 'italian', "
      "NULL, 2, NULL, NULL, 'Rome', NULL, 'Italy', 'old place italian rome italy')",
    );
    raw.execute(
      "INSERT INTO visits VALUES ('v1', 'r1', 1700000000000, 4, 'nice', 2)",
    );
    raw.execute(
      "INSERT INTO photos VALUES ('p1', 'r1', NULL, '/tmp/p1.jpg', 0)",
    );
    raw.execute('PRAGMA user_version = 15');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(File(dbPath)));
    final restaurants = await upgraded.select(upgraded.restaurants).get();
    final visits = await upgraded.select(upgraded.visits).get();
    final photos = await upgraded.select(upgraded.photos).get();

    expect(restaurants, hasLength(1));
    expect(visits, hasLength(1));
    expect(photos, hasLength(1));

    final restaurant = restaurants.single;
    expect(restaurant.id, 'r1');
    expect(restaurant.name, 'Old place');
    expect(restaurant.groupId, isNull, reason: 'existing rows stay private');
    expect(restaurant.createdBy, isNull);
    expect(restaurant.updatedAt, 0, reason: 'not stamped since the upgrade');
    expect(restaurant.deletedAt, isNull);

    expect(visits.single.groupId, isNull);
    expect(visits.single.updatedAt, 0);
    expect(photos.single.groupId, isNull);
    expect(photos.single.updatedAt, 0);

    await upgraded.close();
  });
}
