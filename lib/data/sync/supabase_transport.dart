import 'package:supabase/supabase.dart';

import 'remote_models.dart';
import 'sync_transport.dart';

/// The real [SyncTransport], over the Supabase client.
///
/// Deliberately thin: the network behaviour has no server in the test suite to
/// run against, so everything testable — the JSON mapping below — lives in
/// plain top-level functions the tests exercise directly. Pushes upsert by
/// `id` (idempotent, the same protocol the file-sharing path already uses);
/// pulls filter `group_id` and `updated_at > since` so each pull is
/// incremental and scoped to one group.
class SupabaseSyncTransport implements SyncTransport {
  SupabaseSyncTransport(this._client);

  final SupabaseClient _client;

  @override
  Future<void> pushRestaurants(List<RemoteRestaurant> rows) async {
    if (rows.isEmpty) {
      return;
    }
    await _client.from('restaurants').upsert(
      <Map<String, dynamic>>[for (final RemoteRestaurant r in rows) restaurantToJson(r)],
      onConflict: 'id',
    );
  }

  @override
  Future<void> pushVisits(List<RemoteVisit> rows) async {
    if (rows.isEmpty) {
      return;
    }
    await _client.from('visits').upsert(
      <Map<String, dynamic>>[for (final RemoteVisit v in rows) visitToJson(v)],
      onConflict: 'id',
    );
  }

  @override
  Future<GroupPull> pullGroup({
    required String groupId,
    String? since,
  }) async {
    final List<RemoteRestaurant> restaurants = await _pullRestaurants(
      groupId,
      since,
    );
    final List<RemoteVisit> visits = await _pullVisits(groupId, since);
    return GroupPull(
      restaurants: restaurants,
      visits: visits,
      cursor: _newestIso(<String?>[
        ...restaurants.map((RemoteRestaurant r) => r.updatedAt),
        ...visits.map((RemoteVisit v) => v.updatedAt),
      ]),
    );
  }

  Future<List<RemoteRestaurant>> _pullRestaurants(
    String groupId,
    String? since,
  ) async {
    var query = _client.from('restaurants').select().eq('group_id', groupId);
    if (since != null) {
      query = query.gt('updated_at', since);
    }
    final rows = await query;
    return <RemoteRestaurant>[
      for (final Map<String, dynamic> row in rows) restaurantFromJson(row),
    ];
  }

  Future<List<RemoteVisit>> _pullVisits(String groupId, String? since) async {
    var query = _client.from('visits').select().eq('group_id', groupId);
    if (since != null) {
      query = query.gt('updated_at', since);
    }
    final rows = await query;
    return <RemoteVisit>[
      for (final Map<String, dynamic> row in rows) visitFromJson(row),
    ];
  }
}

/// Serializes a restaurant for an upsert. `updated_at` is deliberately
/// omitted: the server owns it (a column default on insert, a trigger on
/// update), so shipping a client clock would only ever be overwritten.
///
/// The camelCase keys (`cuisineType`, `priceRange`) match the quoted column
/// names in the Supabase schema; the snake_case ones (`group_id`,
/// `created_by`, `deleted_at`) are the schema's own.
Map<String, dynamic> restaurantToJson(RemoteRestaurant r) => <String, dynamic>{
  'id': r.id,
  'group_id': r.groupId,
  'name': r.name,
  'cuisineType': r.cuisineType,
  'address': r.address,
  'priceRange': r.priceRange,
  'website': r.website,
  'instagram': r.instagram,
  'city': r.city,
  'region': r.region,
  'country': r.country,
  'created_by': r.createdBy,
  'deleted_at': r.deletedAt,
};

/// Parses a restaurant as Supabase returns it (the same columns, plus the
/// server-assigned `updated_at`).
RemoteRestaurant restaurantFromJson(Map<String, dynamic> json) =>
    RemoteRestaurant(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      cuisineType: json['cuisineType'] as String,
      address: json['address'] as String?,
      priceRange: (json['priceRange'] as num).toInt(),
      website: json['website'] as String?,
      instagram: json['instagram'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      country: json['country'] as String?,
      createdBy: json['created_by'] as String,
      updatedAt: _asIso(json['updated_at']),
      deletedAt: _asIsoOrNull(json['deleted_at']),
    );

/// Serializes a visit for an upsert, likewise omitting `updated_at`.
Map<String, dynamic> visitToJson(RemoteVisit v) => <String, dynamic>{
  'id': v.id,
  'group_id': v.groupId,
  'restaurant_id': v.restaurantId,
  'visitDate': v.visitDate,
  'rating': v.rating,
  'notes': v.notes,
  'priceRange': v.priceRange,
  'created_by': v.createdBy,
  'deleted_at': v.deletedAt,
};

/// Parses a visit as Supabase returns it.
RemoteVisit visitFromJson(Map<String, dynamic> json) => RemoteVisit(
  id: json['id'] as String,
  groupId: json['group_id'] as String,
  restaurantId: json['restaurant_id'] as String,
  visitDate: (json['visitDate'] as num).toInt(),
  rating: (json['rating'] as num).toInt(),
  notes: json['notes'] as String?,
  priceRange: (json['priceRange'] as num).toInt(),
  createdBy: json['created_by'] as String,
  updatedAt: _asIso(json['updated_at']),
  deletedAt: _asIsoOrNull(json['deleted_at']),
);

/// Reads a remote timestamp as an ISO-8601 string. PostgREST serializes
/// `timestamptz` as a string, but a [DateTime] is accepted defensively so a
/// future SDK change can't turn a pull into a crash.
String _asIso(Object? value) {
  if (value is String) {
    return value;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  throw SyncException('unexpected remote timestamp: $value');
}

String? _asIsoOrNull(Object? value) => value == null ? null : _asIso(value);

/// The lexicographically latest timestamp. All rows in one pull come from the
/// same server, which serializes `timestamptz` in one fixed format, so string
/// order and time order agree.
String? _newestIso(List<String?> timestamps) {
  String? newest;
  for (final String? timestamp in timestamps) {
    if (timestamp == null) {
      continue;
    }
    if (newest == null || timestamp.compareTo(newest) > 0) {
      newest = timestamp;
    }
  }
  return newest;
}
