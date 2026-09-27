import 'package:eatapp/data/sync/remote_models.dart';
import 'package:eatapp/data/sync/sync_transport.dart';

/// A hand-written [SyncTransport] that records pushes and answers pulls from
/// in-memory maps, so the engine can be exercised with no network.
///
/// The fake owns a stable ISO format, so its cursor comparison can stay a
/// plain lexicographic `compareTo` rather than a timestamp parse.
class FakeSyncTransport implements SyncTransport {
  final List<RemoteRestaurant> pushedRestaurants = <RemoteRestaurant>[];
  final List<RemoteVisit> pushedVisits = <RemoteVisit>[];

  /// The table names in push order, for asserting dependency ordering.
  final List<String> pushLog = <String>[];

  /// The remote's rows, keyed by group id.
  final Map<String, List<RemoteRestaurant>> restaurants =
      <String, List<RemoteRestaurant>>{};
  final Map<String, List<RemoteVisit>> visits = <String, List<RemoteVisit>>{};

  @override
  Future<void> pushRestaurants(List<RemoteRestaurant> rows) async {
    pushLog.add('restaurants');
    pushedRestaurants.addAll(rows);
  }

  @override
  Future<void> pushVisits(List<RemoteVisit> rows) async {
    pushLog.add('visits');
    pushedVisits.addAll(rows);
  }

  @override
  Future<GroupPull> pullGroup({
    required String groupId,
    String? since,
  }) async {
    final List<RemoteRestaurant> rs = (restaurants[groupId] ??
            const <RemoteRestaurant>[])
        .where((RemoteRestaurant r) => _after(r.updatedAt, since))
        .toList();
    final List<RemoteVisit> vs =
        (visits[groupId] ?? const <RemoteVisit>[])
            .where((RemoteVisit v) => _after(v.updatedAt, since))
            .toList();
    return GroupPull(
      restaurants: rs,
      visits: vs,
      cursor: _newest(<String?>[
        ...rs.map((RemoteRestaurant r) => r.updatedAt),
        ...vs.map((RemoteVisit v) => v.updatedAt),
      ]),
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
