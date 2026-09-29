import 'package:flutter/foundation.dart';

import 'sync_engine.dart';

/// How the last sync attempt went, for a screen to show.
enum SyncStatus { idle, syncing, succeeded, failed }

/// Drives the [SyncEngine] and publishes what happened, so a screen can show
/// "syncing…" / "synced" / an error and offer a retry.
///
/// Which group to sync is the caller's to know (the group the user has
/// selected), so this holds no active-group state of its own: it is a thin,
/// observable front for the engine, not a scheduler.
class SyncService {
  SyncService(this._engine);

  final SyncEngine _engine;

  /// The last attempt's outcome. Starts [SyncStatus.idle] and never returns to
  /// it, so the UI can tell "never synced" from "synced".
  final ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(
    SyncStatus.idle,
  );

  Object? _lastError;

  /// True while an engine run is in flight, so extra requests coalesce instead
  /// of stacking. A poll tick, an auto-push after a write and a manual tap can
  /// all land within the same moment.
  bool _running = false;

  /// Set when a call arrives while [_running]; the in-flight loop runs once
  /// more so the request is never silently dropped.
  bool _rerunRequested = false;

  /// The error the last failed attempt threw, or null after a success. Read
  /// alongside [status] to decide what to show.
  Object? get lastError => _lastError;

  /// Pushes this device's changes for [groupId] and pulls the group's back,
  /// recording the outcome rather than throwing: a sync failing is a normal
  /// state for the UI to render, not an error for the caller to handle.
  ///
  /// Calls that arrive while a run is in flight are coalesced into at most one
  /// extra pass rather than run concurrently — the engine is not re-entrant,
  /// and overlapping runs would race on the same queue and cursor.
  Future<void> syncGroup(String groupId) async {
    if (_running) {
      _rerunRequested = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerunRequested = false;
        await _runOnce(groupId);
      } while (_rerunRequested);
    } finally {
      _running = false;
    }
  }

  Future<void> _runOnce(String groupId) async {
    status.value = SyncStatus.syncing;
    try {
      await _engine.syncGroup(groupId);
      _lastError = null;
      status.value = SyncStatus.succeeded;
    } catch (error, stackTrace) {
      _lastError = error;
      status.value = SyncStatus.failed;
      // The UI can only offer "retry", so the actual cause — a lost session,
      // no network, an RLS rejection — is logged where a developer can see it.
      debugPrint('Syncing group $groupId failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void dispose() => status.dispose();
}
