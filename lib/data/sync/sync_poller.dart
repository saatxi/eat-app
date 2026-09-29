import 'dart:async';

import 'sync_service.dart';

/// Runs [SyncService.syncGroup] on a timer while a group is selected, so the
/// rest of the group's changes show up without a manual tap or a restart.
///
/// This is the "more online" half of the sync layer: the manual button stays,
/// but it is no longer the only way a pull happens. Polling (rather than
/// Supabase Realtime) was chosen deliberately — it needs no `supabase_realtime`
/// publication and no long-lived connection, which fits a local-first app and
/// keeps the backend's free tier untouched.
///
/// The poller holds only the current group id; every tick delegates to
/// [SyncService], whose own coalescing guard means a slow pull can never have
/// ticks stack up behind it.
class SyncPoller {
  SyncPoller(this._sync, {this.interval = const Duration(seconds: 15)});

  final SyncService _sync;

  /// How often a selected group is pulled. Kept modest: the auto-push after a
  /// write means this is a safety net, not the primary way data arrives.
  final Duration interval;

  Timer? _timer;
  String? _groupId;
  bool _disposed = false;

  /// The group currently being polled, or null when the poller is idle.
  String? get groupId => _groupId;

  /// Points the poller at [groupId] (a group to poll) or null (nothing
  /// selected, so stop). Selecting the same group again is a no-op; switching
  /// groups restarts the timer so the first tick is a full interval away.
  void setGroup(String? groupId) {
    if (_disposed || groupId == _groupId) {
      return;
    }
    _groupId = groupId;
    _timer?.cancel();
    _timer = null;
    if (groupId != null) {
      _timer = Timer.periodic(interval, (_) => _tick());
    }
  }

  void _tick() {
    final String? groupId = _groupId;
    if (_disposed || groupId == null) {
      return;
    }
    // Fire and forget: the poll tick is not awaited by anything, and any error
    // is already recorded on the service's status notifier.
    unawaited(_sync.syncGroup(groupId));
  }

  /// Cancels the timer. Idempotent, and safe to call after disposal.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
