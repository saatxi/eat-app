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

  /// Upserts [rows] to the remote.
  Future<void> pushVisits(List<RemoteVisit> rows);

  /// Fetches every row in [groupId] whose `updated_at` is strictly newer than
  /// [since], across both shared tables, in one request.
  Future<GroupPull> pullGroup({required String groupId, String? since});
}

/// One pull's answer: the changed rows plus the cursor to store next.
class GroupPull {
  const GroupPull({
    required this.restaurants,
    required this.visits,
    required this.cursor,
  });

  final List<RemoteRestaurant> restaurants;
  final List<RemoteVisit> visits;

  /// The newest remote `updated_at` seen across both tables — the value to
  /// store as the next [since]. Null when neither table had a row newer than
  /// the requested [since], in which case the previous cursor stands.
  final String? cursor;
}
