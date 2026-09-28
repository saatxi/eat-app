import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/groups/group_models.dart';
import '../../data/sync/sync_service.dart';
import 'groups_controller.dart';
import 'join_screen.dart';
import 'members_screen.dart';

/// The Groups half of the settings screen: which scope the app is in, and the
/// management that the journal's chip row used to carry — creating a group,
/// joining one, seeing the members of the picked group, and its sync state.
///
/// Only ever built when [GroupsController.canUseGroups] is true, so a build
/// without a backend never renders it at all.
class GroupSettingsSection extends StatelessWidget {
  const GroupSettingsSection({super.key, required this.controller});

  final GroupsController controller;

  /// Creates a group from a one-field dialog, then reports a failure rather
  /// than letting the dialog close with nothing to show for it.
  Future<void> _createGroup(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateGroupDialog(),
    );
    if (result == null) {
      return;
    }
    if (!await controller.createGroup(result)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupsCreateErrorFailed)),
      );
    }
  }

  void _join(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const JoinScreen(),
      ),
    );
  }

  void _openMembers(BuildContext context, Group group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MembersScreen(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final GroupsState state = controller.state;
        final Group? selected = state.selected;
        return Column(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.groupsScopePersonal),
              trailing: state.selectedGroupId == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => controller.select(null),
            ),
            // The whole roster, so a group can still be picked here even though
            // the journal only shows the one in force.
            for (final Group group in state.groups)
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text(group.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // The sync state belongs to the group in force, so it rides
                    // on that group's row.
                    if (state.selectedGroupId == group.id &&
                        controller.sync != null)
                      _SyncIndicator(controller: controller),
                    if (state.selectedGroupId == group.id)
                      const Icon(Icons.check_rounded),
                  ],
                ),
                onTap: () => controller.select(group.id),
              ),
            // Members are only meaningful for a group, and only the picked one.
            if (selected != null)
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(l10n.groupsMembersTitle),
                onTap: () => _openMembers(context, selected),
              ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(l10n.groupsActionCreate),
              onTap: () => _createGroup(context),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_rounded),
              title: Text(l10n.groupsActionJoin),
              onTap: () => _join(context),
            ),
          ],
        );
      },
    );
  }
}

/// The "new group" dialog: one name field and its two actions.
///
/// A [StatefulWidget] purely so it can own the field's [TextEditingController]
/// and dispose it when the dialog itself is torn down, rather than leaving the
/// caller to guess when the route has finished animating away.
class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _name.text.trim();
    if (value.isNotEmpty) {
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.groupsCreateTitle),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.groupsFieldName),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.groupsCreateAction)),
      ],
    );
  }
}

/// The selected group's sync state: a spinner while it runs, a retry when it
/// fails, and a "sync now" otherwise. Only ever built inside a selected group.
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.controller});

  final GroupsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SyncService sync = controller.sync!;
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (BuildContext context, SyncStatus status, Widget? child) {
        switch (status) {
          case SyncStatus.syncing:
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
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
              onPressed: controller.syncNow,
              tooltip: l10n.groupsSyncFailed,
              icon: const Icon(Icons.cloud_off_rounded),
            );
          case SyncStatus.idle:
          case SyncStatus.succeeded:
            return IconButton(
              onPressed: controller.syncNow,
              tooltip: l10n.groupsSyncNow,
              icon: const Icon(Icons.sync_rounded),
            );
        }
      },
    );
  }
}
