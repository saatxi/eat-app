import 'package:drift/drift.dart' show Value;
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/sync/photo_blob_sync.dart';
import 'package:eatapp/data/sync/remote_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';
import '../photo/photo_fakes.dart';
import 'fake_photo_blob_store.dart';

/// [PhotoBlobSync] on its own — constructed directly rather than reached
/// through [SyncEngine], to prove the split genuinely stands alone.
void main() {
  late FakePhotoStorage storage;
  late FakePhotoBlobStore blobs;
  late PhotoBlobSync sync;

  setUp(() {
    storage = FakePhotoStorage();
    blobs = FakePhotoBlobStore();
    sync = PhotoBlobSync(photoStorage: storage, blobs: blobs);
  });

  test('uploadMissing uploads a live row but skips a tombstone', () async {
    storage.files['local/a.jpg'] = <int>[1, 2, 3];
    final Photo live = photo(id: 'p1', path: 'local/a.jpg');
    final Photo tombstone = photo(
      id: 'p2',
      path: 'local/b.jpg',
    ).copyWith(deletedAt: const Value<int?>(1));
    final List<RemotePhoto> remotes = <RemotePhoto>[
      _remote('p1', 'g1/p1'),
      _remote('p2', 'g1/p2'),
    ];

    await sync.uploadMissing(<Photo>[live, tombstone], remotes);

    expect(blobs.uploadLog, <String>['g1/p1']);
  });

  test('downloadAll skips a failed binary rather than aborting the batch',
      () async {
    blobs.failingDownloadPath = 'g1/p9';
    final List<RemotePhoto> remotes = <RemotePhoto>[
      _remote('p1', 'g1/p1'),
      _remote('p9', 'g1/p9'),
    ];
    blobs.objects['g1/p1'] = <int>[9];

    final Map<String, String> paths = await sync.downloadAll(remotes);

    expect(paths.containsKey('p9'), isFalse);
    expect(paths['p1'], isNotNull);
  });

  test('deleteFiles skips a photo with no local path', () async {
    await sync.deleteFiles(<Photo>[
      photo(id: 'p1', path: 'local/a.jpg'),
      photo(id: 'p2', path: ''),
    ]);

    expect(storage.deleted, <String>['local/a.jpg']);
  });
}

RemotePhoto _remote(String id, String storagePath) => RemotePhoto(
  id: id,
  groupId: 'g1',
  restaurantId: null,
  visitId: null,
  position: 0,
  storagePath: storagePath,
  createdBy: 'u1',
  updatedAt: '2026-01-01T00:00:00.000Z',
  deletedAt: null,
);
