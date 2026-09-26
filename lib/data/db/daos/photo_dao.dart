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

  /// The first restaurant-level photo of every restaurant that has one, keyed by
  /// restaurant id — the single thumbnail the list and roulette rows draw.
  ///
  /// Restaurant-level photos are effectively one per restaurant in this UI, so
  /// the lowest `position` wins when a row somehow carries more.
  Stream<Map<String, String>> observeRestaurantPhotoPaths() => customSelect(
    'SELECT restaurantId, path FROM photos WHERE restaurantId IS NOT NULL '
    'ORDER BY restaurantId ASC, position ASC',
    readsFrom: <ResultSetImplementation>{photos},
  ).watch().map((List<QueryRow> rows) {
    final Map<String, String> byRestaurant = <String, String>{};
    for (final QueryRow row in rows) {
      byRestaurant.putIfAbsent(
        row.read<String>('restaurantId'),
        () => row.read<String>('path'),
      );
    }
    return byRestaurant;
  });

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

  /// One-shot: every restaurant-level photo, in position order.
  Future<List<Photo>> getPhotosForRestaurant(String restaurantId) =>
      customSelect(
        'SELECT * FROM photos WHERE restaurantId = ? ORDER BY position ASC',
        variables: <Variable<Object>>[Variable<String>(restaurantId)],
        readsFrom: <ResultSetImplementation>{photos},
      ).get().then(_mapPhotos);

  /// One-shot: the photos taken on one visit.
  Future<List<Photo>> getPhotosForVisit(String visitId) => customSelect(
    'SELECT * FROM photos WHERE visitId = ? ORDER BY position ASC',
    variables: <Variable<Object>>[Variable<String>(visitId)],
    readsFrom: <ResultSetImplementation>{photos},
  ).get().then(_mapPhotos);

  /// Every photo of a visit, or restaurant-level, belonging to one restaurant —
  /// used before a delete so the files on disk can go with the rows.
  Future<List<Photo>> getAllPhotosForRestaurant(String restaurantId) =>
      customSelect(
        'SELECT p.* FROM photos p '
        'LEFT JOIN visits v ON p.visitId = v.id '
        'WHERE p.restaurantId = ? OR v.restaurantId = ?',
        variables: <Variable<Object>>[
          Variable<String>(restaurantId),
          Variable<String>(restaurantId),
        ],
        readsFrom: <ResultSetImplementation>{photos, visits},
      ).get().then(_mapPhotos);

  /// The photos taken on any of a restaurant's visits — the restaurant-level
  /// photo is deliberately excluded, for the visit-rewrite path that must not
  /// touch it.
  Future<List<Photo>> getVisitPhotosForRestaurant(String restaurantId) =>
      customSelect(
        'SELECT p.* FROM photos p '
        'JOIN visits v ON p.visitId = v.id '
        'WHERE v.restaurantId = ?',
        variables: <Variable<Object>>[Variable<String>(restaurantId)],
        readsFrom: <ResultSetImplementation>{photos, visits},
      ).get().then(_mapPhotos);

  /// Every stored photo, for the whole-list wipe.
  Future<List<Photo>> getAllPhotos() =>
      select(photos).get();

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
