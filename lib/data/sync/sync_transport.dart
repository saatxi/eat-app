import 'remote_models.dart';

/// Everything the sync engine needs from the remote, and nothing more.
///
/// The real implementation wraps the Supabase client — upserts on push, an
/// `updated_at >` filter on pull — while tests supply a hand-written fake, the
/// same way [`IdentityGateway`](../supabase/identity.dart) hides gotrue. The
/// transport is the only type in the sync layer that knows the remote exists,
/// and it speaks in [RemoteRestaurant]/[RemoteVisit], never in drift rows.
abstract class SyncTransport {
  /// Upserts [rows] to the remote, in the given order (restaurants first, as
  /// the caller ensures).
  Future<void> pushRestaurants(List<RemoteRestaurant> rows);

  /// Upserts restaurant↔group memberships. A membership references its
  /// restaurant, so the engine pushes restaurants first.
  Future<void> pushRestaurantGroups(List<RemoteRestaurantGroup> rows);

  /// Upserts [rows] to the remote.
  Future<void> pushVisits(List<RemoteVisit> rows);

  /// Upserts [rows] to the remote. The photo's *binary* is uploaded separately
  /// (and first) by the engine; this carries only the row and its
  /// `storage_path`.
  Future<void> pushPhotos(List<RemotePhoto> rows);

  /// Fetches every row in [groupId] whose `updated_at` is strictly newer than
  /// [since]: the memberships that changed, and the restaurants, visits and
  /// photos of every restaurant the group holds — not only of the ones whose
  /// membership changed, or an edit or a new visit would never reach the rest
  /// of the group.
  ///
  /// With [restaurantIds], the pull is instead scoped to those restaurants and
  /// ignores [since] altogether: their memberships in [groupId] and all of
  /// their rows, whatever their age. The engine uses it to fetch restaurants it
  /// finds missing behind a cursor that has already moved past them.
  Future<GroupPull> pullGroup({
    required String groupId,
    String? since,
    List<String>? restaurantIds,
  });
}

/// One pull's answer: the changed rows plus the cursor to store next.
class GroupPull {
  const GroupPull({
    required this.restaurants,
    required this.restaurantGroups,
    required this.visits,
    required this.photos,
    required this.cursor,
    this.liveRestaurantIds = const <String>[],
  });

  final List<RemoteRestaurant> restaurants;

  /// The memberships that changed in this group — the rows that name which
  /// restaurants belong to it, including tombstones for ones removed.
  final List<RemoteRestaurantGroup> restaurantGroups;
  final List<RemoteVisit> visits;
  final List<RemotePhoto> photos;

  /// The newest remote `updated_at` seen across every table — the value to
  /// store as the next [since]. Null when no table had a row newer than the
  /// requested [since], in which case the previous cursor stands.
  final String? cursor;

  /// Every restaurant with a live membership in the group right now, however
  /// long ago it was added — what the device must hold for the group to be
  /// complete, whatever its cursor says.
  final List<String> liveRestaurantIds;
}
