import 'package:drift/drift.dart';

/// The drift mirror of the Android app's Room schema (version 14).
///
/// Column and table names are given explicitly so the generated SQLite schema
/// matches the one Room wrote — that is what lets the Room→drift import read an
/// existing install's `eatapp.db` without a translation table. The
/// `@DataClassName` annotations keep the generated row classes named the same
/// as the Room entities they replace.

/// Sync metadata shared by every table that can belong to a group.
///
/// These four columns are what the sync layer (phase 2) pushes and pulls on:
/// `groupId` NULL means the row is private to this device and never leaves
/// it; `createdBy` records who made the row once it is shared; `updatedAt`
/// is the last-write-wins arbiter; and `deletedAt` marks tombstones, because
/// shared rows are never hard-deleted — a pull has to be able to deliver the
/// deletion to every member.
///
/// Column names match the Supabase schema in `supabase/migrations/` so the
/// sync layer maps rows without a translation table.
mixin GroupSyncColumns on Table {
  /// The group this row belongs to, or null for a private, never-synced row.
  TextColumn get groupId => text().named('groupId').nullable()();

  /// Auth user id of whoever created the row; null while the row is private.
  TextColumn get createdBy => text().named('createdBy').nullable()();

  /// Epoch millis of the last write, set by the repository on every change.
  /// Defaults to 0 ("never written since the 15→16 upgrade"); the repository
  /// stamps the real value on every insert and update.
  IntColumn get updatedAt => integer().named('updatedAt').withDefault(const Constant(0))();

  /// Epoch millis of the soft delete, or null while the row is alive.
  IntColumn get deletedAt => integer().named('deletedAt').nullable()();
}

/// A restaurant's own, place-level facts. Per-visit data (rating, notes, date)
/// lives in [Visits]; whether a place has been visited at all is derived from
/// whether it has any [Visits] rows, not stored here.
@DataClassName('Restaurant')
@TableIndex(name: 'index_restaurants_name', columns: {#name})
class Restaurants extends Table with GroupSyncColumns {
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

/// One visit to a restaurant: when, how it rated, and any free-text note about
/// that specific visit. A restaurant with zero visits is a "want to try" entry;
/// one or more is "visited". Cascades on delete when its restaurant is removed.
@DataClassName('Visit')
@TableIndex(name: 'index_visits_restaurantId', columns: {#restaurantId})
class Visits extends Table with GroupSyncColumns {
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
class Photos extends Table with GroupSyncColumns {
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

/// The local queue of shared rows that still need to be pushed to the remote.
///
/// One entry per dirty row, keyed by (table, row) so repeated writes to the
/// same row coalesce into one entry instead of accumulating. The queue records
/// *which* rows changed; a push reads the row's current state from its own
/// table, so an edit that lands after the enqueue (or a tombstone whose
/// `deletedAt` was set) pushes the latest shape, not a snapshot of the moment
/// it was enqueued.
///
/// This table and [SyncCursors] are drift-only: they were added for the shared
/// groups sync layer and have no Room counterpart, which is why they sit after
/// the three imported tables rather than among them.
@DataClassName('PendingSync')
@TableIndex(name: 'index_pending_syncs_groupId', columns: {#groupId})
class PendingSyncs extends Table {
  @override
  String get tableName => 'pending_syncs';

  /// Which shared table the dirty row lives in: the Dart name of one of the
  /// `SyncTable` values (`restaurants`, `visits` or `photos`), which is the
  /// same string on both the drift and the Supabase side.
  TextColumn get sharedTable => text().named('sharedTable')();

  /// The dirty row's id — a client-generated UUID.
  TextColumn get rowId => text().named('rowId')();

  /// The group the row belongs to, copied at enqueue time so a push can be
  /// scoped to one group without joining back to the source row first.
  TextColumn get groupId => text().named('groupId')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{sharedTable, rowId};
}

/// Which groups a shared restaurant belongs to — the many-to-many membership
/// that replaced the single nullable `groupId` on [Restaurants].
///
/// A private restaurant has no row here. A shared one has one row per group it
/// is in, each also carrying the sync metadata: `createdBy` (who shared it),
/// `updatedAt` (the LWW arbiter for membership changes) and `deletedAt` (a
/// tombstone, so "removed from group X" reaches every member on the next pull).
///
/// `visits` and `photos` stay children of the restaurant and inherit its
/// visibility, so they do not repeat this membership; a restaurant's own
/// `groupId` column remains only as its **home group** — the group it was first
/// shared into, which names the Storage folder for its photo.
@DataClassName('RestaurantGroup')
@TableIndex(name: 'index_restaurant_groups_groupId', columns: {#groupId})
@TableIndex(name: 'index_restaurant_groups_restaurantId', columns: {#restaurantId})
class RestaurantGroups extends Table {
  @override
  String get tableName => 'restaurant_groups';

  /// The shared restaurant. Cascades, so deleting a restaurant drops its
  /// memberships with it.
  TextColumn get restaurantId => text()
      .named('restaurantId')
      .references(Restaurants, #id, onDelete: KeyAction.cascade)();

  /// The group it is shared into. Never null: a membership is always scoped.
  TextColumn get groupId => text().named('groupId')();

  /// Auth user id of whoever shared the restaurant into the group.
  TextColumn get createdBy => text().named('createdBy')();

  /// Epoch millis of the last membership write — the LWW arbiter.
  IntColumn get updatedAt =>
      integer().named('updatedAt').withDefault(const Constant(0))();

  /// Epoch millis of the soft delete (removed from this group), or null while
  /// the membership is live.
  IntColumn get deletedAt => integer().named('deletedAt').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{restaurantId, groupId};
}

/// One row per group the device is a member of, holding this device's pull
/// cursor: the newest remote `updated_at` it has already applied.
///
/// The remote timestamp is stored verbatim as the ISO-8601 string Supabase
/// sent, so the next pull can pass it straight back into an `updated_at >`
/// comparison without any clock or precision conversion in between.
@DataClassName('SyncCursor')
class SyncCursors extends Table {
  @override
  String get tableName => 'sync_cursors';

  /// The group this cursor advances for.
  TextColumn get groupId => text().named('groupId')();

  /// ISO-8601 `updated_at` of the newest remote row already pulled.
  TextColumn get lastPulledAt => text().named('lastPulledAt')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{groupId};
}
