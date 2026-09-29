import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/sync/pending_sync_store.dart';
import 'package:eatapp/data/sync/remote_models.dart';
import 'package:eatapp/data/sync/sync_cursor_store.dart';
import 'package:eatapp/data/sync/sync_engine.dart';
import 'package:eatapp/data/sync/sync_table.dart';
import 'package:flutter_test/flutter_test.dart';

import '../photo/photo_fakes.dart';
import 'fake_photo_blob_store.dart';
import 'fake_sync_transport.dart';

Restaurant sharedRestaurant() => Restaurant(
  id: 'r1',
  groupId: 'g1',
  name: 'Cal Ferran',
  cuisineType: 'italian',
  priceRange: 2,
  searchText: 'cal ferran italian',
  createdBy: 'u1',
  updatedAt: 1000,
);

Visit sharedVisit() => Visit(
  id: 'v1',
  groupId: 'g1',
  restaurantId: 'r1',
  visitDate: 1700000000000,
  rating: 4,
  notes: null,
  priceRange: 2,
  createdBy: 'u1',
  updatedAt: 1000,
);

RemoteRestaurant remoteRestaurant({
  String id = 'r9',
  String updatedAt = '2026-09-27T10:00:00.000Z',
  String? deletedAt,
}) => RemoteRestaurant(
  id: id,
  groupId: 'g1',
  name: 'Remote',
  cuisineType: 'italian',
  address: null,
  priceRange: 2,
  website: null,
  instagram: null,
  city: null,
  region: null,
  country: null,
  createdBy: 'u1',
  updatedAt: updatedAt,
  deletedAt: deletedAt,
);

Photo sharedPhoto() => Photo(
  id: 'p1',
  groupId: 'g1',
  restaurantId: 'r1',
  path: 'stored/local.jpg',
  position: 0,
  createdBy: 'u1',
  updatedAt: 1000,
);

RemotePhoto remotePhoto({String id = 'p9', String? deletedAt}) => RemotePhoto(
  id: id,
  groupId: 'g1',
  restaurantId: null,
  visitId: null,
  position: 0,
  storagePath: 'g1/$id',
  createdBy: 'u1',
  updatedAt: '2026-09-27T10:00:00.000Z',
  deletedAt: deletedAt,
);

RemoteVisit remoteVisit({
  String id = 'v9',
  String restaurantId = 'r9',
  String updatedAt = '2026-09-27T10:00:00.000Z',
}) => RemoteVisit(
  id: id,
  groupId: 'g1',
  restaurantId: restaurantId,
  visitDate: 1700000000000,
  rating: 3,
  notes: null,
  priceRange: 1,
  createdBy: 'u1',
  updatedAt: updatedAt,
  deletedAt: null,
);

void main() {
  late AppDatabase db;
  late PendingSyncStore pending;
  late SyncCursorStore cursors;
  late FakeSyncTransport transport;
  late FakePhotoStorage photoStorage;
  late FakePhotoBlobStore blobs;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.memory();
    pending = PendingSyncStore(db);
    cursors = SyncCursorStore(db);
    transport = FakeSyncTransport();
    photoStorage = FakePhotoStorage();
    blobs = FakePhotoBlobStore();
    engine = SyncEngine(
      database: db,
      pending: pending,
      cursors: cursors,
      transport: transport,
      photoStorage: photoStorage,
      blobs: blobs,
    );
  });

  tearDown(() => db.close());

  test('pushGroup sends restaurants before visits and drains the queue', () async {
    await db.into(db.restaurants).insert(sharedRestaurant());
    await db.into(db.visits).insert(sharedVisit());
    // Enqueued out of order: the store must still order restaurants first.
    await pending.enqueue(SyncTable.visits, 'v1', 'g1');
    await pending.enqueue(SyncTable.restaurants, 'r1', 'g1');

    await engine.pushGroup('g1');

    expect(transport.pushLog, <String>['restaurants', 'visits']);
    expect(transport.pushedRestaurants.map((r) => r.id), <String>['r1']);
    expect(transport.pushedVisits.map((v) => v.id), <String>['v1']);
    expect(transport.pushedRestaurants.single.createdBy, 'u1');
    expect(transport.pushedRestaurants.single.updatedAt, isoFromEpochMillis(1000));
    expect(await pending.pendingForGroup('g1'), isEmpty);
  });

  test('pushGroup is a no-op when the queue is empty', () async {
    await engine.pushGroup('g1');
    expect(transport.pushLog, isEmpty);
  });

  test('pushGroup uploads a photo binary before its row', () async {
    await db.into(db.restaurants).insert(sharedRestaurant());
    await db.into(db.photos).insert(sharedPhoto());
    photoStorage.files['stored/local.jpg'] = <int>[1, 2, 3];
    await pending.enqueue(SyncTable.photos, 'p1', 'g1');

    await engine.pushGroup('g1');

    expect(blobs.uploadLog, <String>['g1/p1']);
    expect(blobs.objects['g1/p1'], <int>[1, 2, 3]);
    expect(transport.pushedPhotos.map((RemotePhoto p) => p.id), <String>['p1']);
    expect(transport.pushedPhotos.single.storagePath, 'g1/p1');
  });

  test('pullGroup downloads a photo binary and points the row at it', () async {
    blobs.objects['g1/p9'] = <int>[9, 9];
    transport.photos['g1'] = <RemotePhoto>[remotePhoto()];

    await engine.pullGroup('g1');

    final Photo row = await db.select(db.photos).getSingle();
    expect(row.id, 'p9');
    expect(row.groupId, 'g1');
    expect(row.path, 'stored/downloaded-0');
    expect(photoStorage.written['stored/downloaded-0'], <int>[9, 9]);
  });

  test('a failed photo download does not abort the rest of the pull', () async {
    transport.restaurants['g1'] = <RemoteRestaurant>[remoteRestaurant()];
    transport.photos['g1'] = <RemotePhoto>[remotePhoto()];
    blobs.failingDownloadPath = 'g1/p9';

    await engine.pullGroup('g1');

    // The restaurant landed even though its photo's binary could not be read.
    expect((await db.select(db.restaurants).get()).single.id, 'r9');
    // The row is still applied, just without a local file this time.
    expect((await db.select(db.photos).getSingle()).path, '');
  });

  test('a pulled photo tombstone writes no file', () async {
    transport.photos['g1'] = <RemotePhoto>[
      remotePhoto(deletedAt: '2026-09-27T11:00:00.000Z'),
    ];

    await engine.pullGroup('g1');

    final Photo row = await db.select(db.photos).getSingle();
    expect(row.deletedAt, isNotNull);
    expect(photoStorage.written, isEmpty);
  });

  test('pullGroup applies remote rows and advances the cursor', () async {
    transport.restaurants['g1'] = <RemoteRestaurant>[remoteRestaurant()];
    transport.visits['g1'] = <RemoteVisit>[remoteVisit()];

    await engine.pullGroup('g1');

    final List<Restaurant> restaurants = await db
        .select(db.restaurants)
        .get();
    final Restaurant row = restaurants.single;
    expect(row.id, 'r9');
    expect(row.groupId, 'g1');
    expect(row.createdBy, 'u1');
    expect(row.searchText, isNotEmpty);
    expect(row.updatedAt, epochMillisFromIso('2026-09-27T10:00:00.000Z'));

    final List<Visit> visits = await db.select(db.visits).get();
    expect(visits.single.id, 'v9');

    expect(await cursors.read('g1'), '2026-09-27T10:00:00.000Z');
    // A pull writes straight to drift, so it must not re-enqueue anything.
    expect(await pending.pendingForGroup('g1'), isEmpty);
  });

  test('a tombstone pulls as a soft-deleted row', () async {
    transport.restaurants['g1'] = <RemoteRestaurant>[
      remoteRestaurant(deletedAt: '2026-09-27T11:00:00.000Z'),
    ];

    await engine.pullGroup('g1');

    final Restaurant row = (await db.select(db.restaurants).get()).single;
    expect(row.deletedAt, epochMillisFromIso('2026-09-27T11:00:00.000Z'));
  });

  test('a pull with nothing newer keeps the previous cursor and writes nothing', () async {
    await cursors.advance('g1', '2026-09-27T10:00:00.000Z');
    transport.restaurants['g1'] = <RemoteRestaurant>[
      remoteRestaurant(updatedAt: '2026-09-27T09:00:00.000Z'),
    ];

    await engine.pullGroup('g1');

    expect(await cursors.read('g1'), '2026-09-27T10:00:00.000Z');
    expect(await db.select(db.restaurants).get(), isEmpty);
  });

  test('syncGroup pushes first, then pulls', () async {
    await db.into(db.restaurants).insert(sharedRestaurant());
    await pending.enqueue(SyncTable.restaurants, 'r1', 'g1');
    transport.restaurants['g1'] = <RemoteRestaurant>[remoteRestaurant()];
    transport.visits['g1'] = <RemoteVisit>[remoteVisit()];

    await engine.syncGroup('g1');

    expect(transport.pushedRestaurants.map((r) => r.id), <String>['r1']);
    expect((await db.select(db.visits).get()).single.id, 'v9');
    expect(await pending.pendingForGroup('g1'), isEmpty);
  });

  test('syncGroup still pulls when the push fails', () async {
    await db.into(db.restaurants).insert(sharedRestaurant());
    await pending.enqueue(SyncTable.restaurants, 'r1', 'g1');
    transport.pushError = Exception('push refused');
    transport.restaurants['g1'] = <RemoteRestaurant>[remoteRestaurant()];

    // The push failure still reaches the caller...
    await expectLater(
      engine.syncGroup('g1'),
      throwsA(isA<Exception>()),
    );

    // ...but it did not cost us the pull: the other member's row landed.
    final List<Restaurant> rows = await db.select(db.restaurants).get();
    expect(rows.map((Restaurant r) => r.id), contains('r9'));
  });
}
