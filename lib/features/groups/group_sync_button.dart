import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/sync/sync_service.dart';
import 'groups_controller.dart';

/// The selected group's sync state as an app-bar action: a "sync now" button
/// that turns into a spinner while a pull runs and into a "failed — tap to
/// retry" cloud when the last attempt threw.
///
/// Built only where groups are available, and it collapses to nothing whenever
/// no group is selected — a personal list has no remote to refresh, so there is
/// nothing for the button to do.
///
/// A failed attempt also raises a snackbar, because a silent failure is exactly
/// the state a user cannot tell apart from "nothing changed upstream".
class GroupSyncButton extends StatefulWidget {
  const GroupSyncButton({super.key, required this.controller});

  final GroupsController controller;

  @override
  State<GroupSyncButton> createState() => _GroupSyncButtonState();
}

class _GroupSyncButtonState extends State<GroupSyncButton> {
  SyncService? _sync;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(GroupSyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.sync != widget.controller.sync) {
      _sync?.status.removeListener(_onStatusChanged);
      _listen();
    }
  }

  @override
  void dispose() {
    _sync?.status.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _listen() {
    _sync = widget.controller.sync;
    _sync?.status.addListener(_onStatusChanged);
  }

  void _onStatusChanged() {
    if (!mounted || _sync?.status.value != SyncStatus.failed) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).groupsSyncFailed)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final SyncService? sync = widget.controller.sync;
    if (sync == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Listens to the controller as well as the sync status: selecting or
    // leaving a group has to show or hide the button, not just a running pull
    // change its icon.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        if (widget.controller.state.selectedGroupId == null) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<SyncStatus>(
          valueListenable: sync.status,
          builder: (BuildContext context, SyncStatus status, Widget? child) {
            switch (status) {
              case SyncStatus.syncing:
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              case SyncStatus.failed:
                return IconButton(
                  onPressed: widget.controller.syncNow,
                  tooltip: l10n.groupsSyncFailed,
                  icon: const Icon(Icons.cloud_off_rounded),
                );
              case SyncStatus.idle:
              case SyncStatus.succeeded:
                return IconButton(
                  onPressed: widget.controller.syncNow,
                  tooltip: l10n.groupsSyncNow,
                  icon: const Icon(Icons.sync_rounded),
                );
            }
          },
        );
      },
    );
  }
}
