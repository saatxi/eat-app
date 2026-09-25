import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'photo_dao.g.dart';

/// Every stored-photo query, restaurant- and visit-level alike.
@DriftAccessor(tables: <Type>[Photos, Visits])
class PhotoDao extends DatabaseAccessor<AppDatabase> with _$PhotoDaoMixin {
  PhotoDao(super.db);

  Stream<List<Photo>> observePhotosForRestaurant(String restaurantId) =>
      customSelect(
        'SELECT * FROM photos WHERE restaurantId = ? ORDER BY position ASC',
        variables: <Variable<Object>>[Variable<String>(restaurantId)],
        readsFrom: <ResultSetImplementation>{photos},
      ).watch().map(_mapPhotos);

  Stream<List<Photo>> observePhotosForVisit(String visitId) => customSelect(
    'SELECT * FROM photos WHERE visitId = ? ORDER BY position ASC',
    variables: <Variable<Object>>[Variable<String>(visitId)],
    readsFrom: <ResultSetImplementation>{photos},
  ).watch().map(_mapPhotos);

  /// One-shot: the first restaurant-level photo, if any — used to prefill the
  /// edit form.
  Future<Photo?> getFirstPhotoForRestaurant(String restaurantId) =>
      customSelect(
        'SELECT * FROM photos WHERE restaurantId = ? '
        'ORDER BY position ASC LIMIT 1',
        variables: <Variable<Object>>[Variable<String>(restaurantId)],
        readsFrom: <ResultSetImplementation>{photos},
      ).getSingleOrNull().then(
        (QueryRow? row) => row == null ? null : photos.map(row.data),
      );

  Future<Photo?> getById(String id) => customSelect(
    'SELECT * FROM photos WHERE id = ?',
    variables: <Variable<Object>>[Variable<String>(id)],
    readsFrom: <ResultSetImplementation>{photos},
  ).getSingleOrNull().then(
    (QueryRow? row) => row == null ? null : photos.map(row.data),
  );

  /// -1 when the restaurant has no photos yet, so a caller can always append at
  /// `+ 1`.
  Future<int> getMaxPositionForRestaurant(String restaurantId) => customSelect(
    'SELECT COALESCE(MAX(position), -1) AS position FROM photos '
    'WHERE restaurantId = ?',
    variables: <Variable<Object>>[Variable<String>(restaurantId)],
    readsFrom: <ResultSetImplementation>{photos},
  ).getSingle().then((QueryRow row) => row.read<int>('position'));

  Future<void> insertPhoto(Photo row) => into(photos).insert(row);

  Future<void> deletePhoto(String id) =>
      (delete(photos)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAllPhotosForRestaurant(String restaurantId) =>
      (delete(photos)..where((t) => t.restaurantId.equals(restaurantId))).go();

  List<Photo> _mapPhotos(List<QueryRow> rows) => <Photo>[
    for (final QueryRow row in rows) photos.map(row.data),
  ];
}
