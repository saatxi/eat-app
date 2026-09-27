/// The three shared tables, in push dependency order.
///
/// The order is load-bearing: a visit references its restaurant, and a photo
/// references its restaurant or its visit, so a push must send restaurants
/// before visits and visits before photos — the remote's foreign keys reject
/// an out-of-order row. `SyncTable.values` is therefore the push order, and
/// [SyncTable.name] doubles as the table's name on both sides (drift
/// `tableName` and the Supabase relation), so no mapping is needed.
enum SyncTable {
  restaurants,
  visits,
  photos;
}
