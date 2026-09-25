import 'package:drift/drift.dart';

/// The drift mirror of the Android app's Room schema (version 14).
///
/// Column and table names are given explicitly so the generated SQLite schema
/// matches the one Room wrote — that is what lets the Room→drift import read an
/// existing install's `eatapp.db` without a translation table. The
/// `@DataClassName` annotations keep the generated row classes named the same
/// as the Room entities they replace.

/// A restaurant's own, place-level facts. Per-visit data (rating, notes, date)
/// lives in [Visits]; whether a place has been visited at all is derived from
/// whether it has any [Visits] rows, not stored here.
@DataClassName('Restaurant')
@TableIndex(name: 'index_restaurants_name', columns: {#name})
class Restaurants extends Table {
  @override
  String get tableName => 'restaurants';

  /// Client-generated UUID string, assigned by the repository at insert time —
  /// never an autoincrement.
  TextColumn get id => text().named('id')();

  TextColumn get name => text().named('name')();

  TextColumn get cuisineType => text().named('cuisineType')();

  /// Street line only — town/region/country live in [city]/[region]/[country].
  /// The physical column stays named `address` for historical continuity with
  /// earlier schemas.
  TextColumn get streetAddress => text().named('address').nullable()();

  /// General price band of the place (0-6, euro tiers) — not per-visit.
  IntColumn get priceRange => integer().named('priceRange')();

  /// Optional links. Both are validated on import and are null whenever the
  /// source data omits the column, leaves it empty, or holds something that
  /// isn't safe to open.
  TextColumn get website => text().named('website').nullable()();

  /// Bare handle, no leading `@` and never a URL.
  TextColumn get instagram => text().named('instagram').nullable()();

  /// Town/city ("poble"). Free text with autocomplete over existing values — no
  /// closed vocabulary, unlike [cuisineType].
  TextColumn get city => text().named('city').nullable()();

  /// State/province ("regió"). Same free-text-with-autocomplete treatment as
  /// [city].
  TextColumn get region => text().named('region').nullable()();

  /// Country ("país"). Same free-text-with-autocomplete treatment as [city].
  TextColumn get country => text().named('country').nullable()();

  /// Accent-stripped, lowercased concatenation of every searchable field —
  /// built by `buildSearchText`, which is what keeps it from drifting.
  TextColumn get searchText => text().named('searchText')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A free-form, user-invented label — "Terraza", "para grupos" — as opposed to
/// the closed `Cuisine` vocabulary. `COLLATE NOCASE` plus the unique index on
/// [name] gives case-insensitive uniqueness at the SQLite level: inserting
/// "terraza" when "Terraza" already exists conflicts against the same row
/// instead of creating a near-duplicate.
@DataClassName('Tag')
@TableIndex(name: 'index_tags_name', columns: {#name}, unique: true)
class Tags extends Table {
  @override
  String get tableName => 'tags';

  TextColumn get id => text().named('id')();

  TextColumn get name =>
      text().named('name').customConstraint('NOT NULL COLLATE NOCASE')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Join row linking a [Restaurants] row to a [Tags] row. Both foreign keys
/// cascade on delete: removing a restaurant or a tag cleans up the links
/// pointing at it without leaving orphaned rows in this table.
@DataClassName('RestaurantTag')
@TableIndex(name: 'index_restaurant_tags_tagId', columns: {#tagId})
class RestaurantTags extends Table {
  @override
  String get tableName => 'restaurant_tags';

  TextColumn get restaurantId => text()
      .named('restaurantId')
      .references(Restaurants, #id, onDelete: KeyAction.cascade)();

  // Without this index, deleting a tag (or any tagId-keyed lookup) forces a
  // full scan of this table: the composite primary key only covers lookups
  // that lead with restaurantId.
  TextColumn get tagId =>
      text().named('tagId').references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{restaurantId, tagId};
}

/// One visit to a restaurant: when, how it rated, and any free-text note about
/// that specific visit. A restaurant with zero visits is a "want to try" entry;
/// one or more is "visited". Cascades on delete when its restaurant is removed.
@DataClassName('Visit')
@TableIndex(name: 'index_visits_restaurantId', columns: {#restaurantId})
class Visits extends Table {
  @override
  String get tableName => 'visits';

  TextColumn get id => text().named('id')();

  TextColumn get restaurantId => text()
      .named('restaurantId')
      .references(Restaurants, #id, onDelete: KeyAction.cascade)();

  /// Epoch millis.
  IntColumn get visitDate => integer().named('visitDate')();

  /// 0-5.
  IntColumn get rating => integer().named('rating')();

  TextColumn get notes => text().named('notes').nullable()();

  /// Price band on this particular visit (0-6, same scale as
  /// `Restaurants.priceRange`); 0 means "not set".
  IntColumn get priceRange => integer().named('priceRange')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A stored photo, attached either to a restaurant directly or to one of its
/// visits — exactly one of [restaurantId]/[visitId] should be non-null in
/// practice (enforced in the repository, not at the DB level). Cascades on
/// delete either way, so removing a restaurant or a visit cleans up its photos.
@DataClassName('Photo')
@TableIndex(name: 'index_photos_restaurantId', columns: {#restaurantId})
@TableIndex(name: 'index_photos_visitId', columns: {#visitId})
class Photos extends Table {
  @override
  String get tableName => 'photos';

  TextColumn get id => text().named('id')();

  TextColumn get restaurantId => text()
      .named('restaurantId')
      .nullable()
      .references(Restaurants, #id, onDelete: KeyAction.cascade)();

  TextColumn get visitId => text()
      .named('visitId')
      .nullable()
      .references(Visits, #id, onDelete: KeyAction.cascade)();

  /// Absolute path to a copy this app made under its own `filesDir/photos/`.
  TextColumn get path => text().named('path')();

  IntColumn get position => integer().named('position')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
