import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/stats_projections.dart';
import '../app_database.dart';
import '../tables.dart';

part 'tag_dao.g.dart';

/// Every free-form tag query.
@DriftAccessor(tables: <Type>[Tags, RestaurantTags, Restaurants])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  static const Uuid _uuid = Uuid();

  /// Inserts [tag] unless one with the same name already exists — the column's
  /// `COLLATE NOCASE` plus its unique index make that check case-insensitive at
  /// the SQLite level. Returns the inserted row, or null when the insert was
  /// ignored because another row won the race.
  Future<Tag?> insertTagIfAbsent(Tag tag) =>
      into(tags).insertReturningOrNull(tag, mode: InsertMode.insertOrIgnore);

  /// `name = ?` is case-insensitive here because the column itself is
  /// `COLLATE NOCASE`.
  Future<String?> findTagId(String name) async {
    final Tag? row =
        await (select(tags)
              ..where((t) => t.name.equals(name))
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  Future<void> deleteLinks(String restaurantId) =>
      (delete(
        restaurantTags,
      )..where((t) => t.restaurantId.equals(restaurantId))).go();

  Future<void> insertLinks(List<RestaurantTag> links) async {
    if (links.isEmpty) {
      return;
    }
    await batch(
      (Batch b) =>
          b.insertAll(restaurantTags, links, mode: InsertMode.insertOrIgnore),
    );
  }

  Future<void> deleteAllTags() => delete(tags).go();

  Stream<List<String>> observeAllTagNames() => customSelect(
    'SELECT name AS name FROM tags ORDER BY name COLLATE NOCASE',
    readsFrom: <ResultSetImplementation>{tags},
  ).watch().map(_readNames);

  Stream<List<String>> observeTagNames(String restaurantId) => customSelect(
    'SELECT t.name AS name FROM tags t '
    'JOIN restaurant_tags rt ON t.id = rt.tagId '
    'WHERE rt.restaurantId = ? ORDER BY t.name COLLATE NOCASE',
    variables: <Variable<Object>>[Variable<String>(restaurantId)],
    readsFrom: <ResultSetImplementation>{tags, restaurantTags},
  ).watch().map(_readNames);

  /// One row per restaurant/tag-name pair — the caller groups them by
  /// restaurant.
  Stream<List<RestaurantTagName>> observeAllRestaurantTagLinks() => customSelect(
    'SELECT rt.restaurantId AS restaurantId, t.name AS name '
    'FROM restaurant_tags rt JOIN tags t ON t.id = rt.tagId',
    readsFrom: <ResultSetImplementation>{tags, restaurantTags},
  ).watch().map(_mapRestaurantTagLinks);

  /// One-shot variant of [observeAllRestaurantTagLinks], used to assemble the
  /// export snapshot without subscribing to a stream that is read once.
  Future<List<RestaurantTagName>> getAllRestaurantTagLinks() => customSelect(
    'SELECT rt.restaurantId AS restaurantId, t.name AS name '
    'FROM restaurant_tags rt JOIN tags t ON t.id = rt.tagId',
    readsFrom: <ResultSetImplementation>{tags, restaurantTags},
  ).get().then(_mapRestaurantTagLinks);

  /// Backs the statistics screen's "top tags" ranking, most-used first.
  Stream<List<TagCount>> observeTagCounts() => customSelect(
    'SELECT t.name AS name, COUNT(*) AS count FROM tags t '
    'JOIN restaurant_tags rt ON t.id = rt.tagId '
    'GROUP BY t.name ORDER BY count DESC, t.name COLLATE NOCASE ASC',
    readsFrom: <ResultSetImplementation>{tags, restaurantTags},
  ).watch().map(
    (List<QueryRow> rows) => <TagCount>[
      for (final QueryRow row in rows)
        TagCount(
          name: row.read<String>('name'),
          count: row.read<int>('count'),
        ),
    ],
  );

  /// Replaces every tag link for [restaurantId] with [tagNames], creating any
  /// tag that doesn't already exist (case-insensitively).
  ///
  /// [tagNames] is de-duplicated up front and every insert ignores conflicts,
  /// so a caller that (by mistake) passes case-insensitive duplicates gets a
  /// no-op instead of a constraint error aborting the whole save.
  Future<void> setTags(String restaurantId, List<String> tagNames) {
    final List<String> uniqueNames = <String>[];
    final Set<String> seen = <String>{};
    for (final String name in tagNames) {
      if (seen.add(name.trim().toLowerCase())) {
        uniqueNames.add(name);
      }
    }

    return transaction(() async {
      await deleteLinks(restaurantId);
      for (final String name in uniqueNames) {
        String? tagId = await findTagId(name);
        if (tagId == null) {
          final Tag? inserted = await insertTagIfAbsent(
            Tag(id: _uuid.v4(), name: name),
          );
          // Null means the IGNORE fired (a concurrent insert won the race
          // between the lookup and the insert) — look the row up again rather
          // than writing a link to a nonexistent tag.
          tagId = inserted?.id ?? await findTagId(name);
        }
        if (tagId != null) {
          await insertLinks(<RestaurantTag>[
            RestaurantTag(restaurantId: restaurantId, tagId: tagId),
          ]);
        }
      }
    });
  }

  List<String> _readNames(List<QueryRow> rows) => <String>[
    for (final QueryRow row in rows) row.read<String>('name'),
  ];

  List<RestaurantTagName> _mapRestaurantTagLinks(List<QueryRow> rows) =>
      <RestaurantTagName>[
        for (final QueryRow row in rows)
          RestaurantTagName(
            restaurantId: row.read<String>('restaurantId'),
            name: row.read<String>('name'),
          ),
      ];
}
