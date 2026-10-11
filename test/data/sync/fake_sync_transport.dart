import 'package:eatapp/data/sync/remote_models.dart';
import 'package:eatapp/data/sync/sync_transport.dart';

/// A hand-written [SyncTransport] that records pushes and answers pulls from
/// in-memory maps, so the engine can be exercised with no network.
///
/// The fake owns a stable ISO format, so its cursor comparison can stay a
/// plain lexicographic `compareTo` rather than a timestamp parse.
class FakeSyncTransport implements SyncTransport {
  final List<RemoteRestaurant> pushedRestaurants = <RemoteRestaurant>[];
  final List<RemoteRestaurantGroup> pushedRestaurantGroups =
      <RemoteRestaurantGroup>[];
  final List<RemoteVisit> pushedVisits = <RemoteVisit>[];
  final List<RemotePhoto> pushedPhotos = <RemotePhoto>[];

  /// The table names in push order, for asserting dependency ordering.
  final List<String> pushLog = <String>[];

  /// The group ids pulled, in order, for asserting that a screen asked for a
  /// sync (and how many times).
  final List<String> pullLog = <String>[];

  /// The restaurant ids of every scoped pull — the engine fetching restaurants
  /// it found missing behind its cursor.
  final List<List<String>> scopedPulls = <List<String>>[];

  /// The remote's rows, keyed by group id.
  final Map<String, List<RemoteRestaurant>> restaurants =
      <String, List<RemoteRestaurant>>{};
  final Map<String, List<RemoteRestaurantGroup>> restaurantGroups =
      <String, List<RemoteRestaurantGroup>>{};
  final Map<String, List<RemoteVisit>> visits = <String, List<RemoteVisit>>{};
  final Map<String, List<RemotePhoto>> photos = <String, List<RemotePhoto>>{};

  /// When set, every restaurant push throws it — to model a server that keeps
  /// refusing a row.
  Object? pushError;

  @override
  Future<void> pushRestaurants(List<RemoteRestaurant> rows) async {
    final Object? failure = pushError;
    if (failure != null) {
      throw failure;
    }
    pushLog.add('restaurants');
    pushedRestaurants.addAll(rows);
  }

  @override
  Future<void> pushRestaurantGroups(List<RemoteRestaurantGroup> rows) async {
    pushLog.add('restaurantGroups');
    pushedRestaurantGroups.addAll(rows);
  }

  @override
  Future<void> pushVisits(List<RemoteVisit> rows) async {
    pushLog.add('visits');
    pushedVisits.addAll(rows);
  }

  @override
  Future<void> pushPhotos(List<RemotePhoto> rows) async {
    pushLog.add('photos');
    pushedPhotos.addAll(rows);
  }

  @override
  Future<GroupPull> pullGroup({
    required String groupId,
    String? since,
    List<String>? restaurantIds,
  }) async {
    pullLog.add(groupId);
    if (restaurantIds != null) {
      scopedPulls.add(restaurantIds);
    }
    // A scoped pull ignores the cursor and keeps only the named restaurants.
    final String? after = restaurantIds == null ? since : null;
    bool inScope(String? restaurantId) =>
        restaurantIds == null || restaurantIds.contains(restaurantId);

    final List<RemoteRestaurantGroup> allRgs =
        restaurantGroups[groupId] ?? const <RemoteRestaurantGroup>[];
    final List<RemoteRestaurantGroup> rgs = allRgs
        .where(
          (RemoteRestaurantGroup rg) =>
              inScope(rg.restaurantId) && _after(rg.updatedAt, after),
        )
        .toList();
    final List<RemoteRestaurant> rs = (restaurants[groupId] ??
            const <RemoteRestaurant>[])
        .where(
          (RemoteRestaurant r) => inScope(r.id) && _after(r.updatedAt, after),
        )
        .toList();
    final List<RemoteVisit> vs =
        (visits[groupId] ?? const <RemoteVisit>[])
            .where(
              (RemoteVisit v) =>
                  inScope(v.restaurantId) && _after(v.updatedAt, after),
            )
            .toList();
    final List<RemotePhoto> ps = (photos[groupId] ?? const <RemotePhoto>[])
        .where(
          (RemotePhoto p) =>
              inScope(p.restaurantId) && _after(p.updatedAt, after),
        )
        .toList();
    return GroupPull(
      restaurants: rs,
      restaurantGroups: rgs,
      visits: vs,
      photos: ps,
      cursor: _newest(<String?>[
        ...rgs.map((RemoteRestaurantGroup rg) => rg.updatedAt),
        ...rs.map((RemoteRestaurant r) => r.updatedAt),
        ...vs.map((RemoteVisit v) => v.updatedAt),
        ...ps.map((RemotePhoto p) => p.updatedAt),
      ]),
      liveRestaurantIds: <String>[
        for (final RemoteRestaurantGroup rg in allRgs)
          if (rg.deletedAt == null && inScope(rg.restaurantId)) rg.restaurantId,
      ],
    );
  }

  static bool _after(String updatedAt, String? since) =>
      since == null || updatedAt.compareTo(since) > 0;

  static String? _newest(List<String?> timestamps) {
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
}
