import 'dart:io';

import 'package:drift/native.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The 14→15 migration: the tag feature is gone, so its two tables — `tags`
/// and `restaurant_tags` — are dropped. The drop is deliberately destructive
/// (nothing reads the rows any more), but every restaurant, visit and photo
/// must survive it.
///
/// A v14 file is the drift mirror of the Android app's Room schema, so it also
/// carries the two tag tables v15 removes. It is built with raw sqlite3 (no
/// drift involved, exactly what a real v14 install has on disk) and then opened
/// by [AppDatabase], whose migration runs 14→15 — and, since the file is three
/// versions behind, the 15→16 and 16→17 steps with it.
void main() {
  test('14→15 drops the tag tables and keeps the core rows', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp('eatapp');
    final String dbPath = '${tempDir.path}/v14.db';
    addTearDown(() => tempDir.delete(recursive: true));

    // Build the v14 file by hand — the schema exactly as v14 wrote it.
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
    // The two tables v15 removes: `tags` (case-insensitive unique name) and the
    // `restaurant_tags` join, both with cascading foreign keys.
    raw.execute('''
      CREATE TABLE tags (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE
      );
    ''');
    raw.execute('CREATE UNIQUE INDEX index_tags_name ON tags (name);');
    raw.execute('''
      CREATE TABLE restaurant_tags (
        restaurantId TEXT NOT NULL REFERENCES restaurants (id) ON DELETE CASCADE,
        tagId TEXT NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
        PRIMARY KEY (restaurantId, tagId)
      );
    ''');
    raw.execute(
      'CREATE INDEX index_restaurant_tags_tagId ON restaurant_tags (tagId);',
    );

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
    raw.execute("INSERT INTO tags VALUES ('t1', 'Terraza'), ('t2', 'grups')");
    raw.execute("INSERT INTO restaurant_tags VALUES ('r1', 't1')");
    raw.execute('PRAGMA user_version = 14');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(File(dbPath)));

    // The core rows survive the whole 14→17 upgrade.
    final restaurants = await upgraded.select(upgraded.restaurants).get();
    final visits = await upgraded.select(upgraded.visits).get();
    final photos = await upgraded.select(upgraded.photos).get();
    expect(restaurants.single.id, 'r1');
    expect(visits.single.id, 'v1');
    expect(photos.single.id, 'p1');

    // The tag tables are gone.
    final tables = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('tags', 'restaurant_tags')",
        )
        .get();
    expect(tables, isEmpty, reason: 'the tag tables must be dropped');

    await upgraded.close();
  });
}
