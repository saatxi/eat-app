import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/group_models.dart';
import '../../data/sync/sync_service.dart';
import 'groups_controller.dart';
import 'join_screen.dart';

/// The scope selector above the list: Personal, each of the user's groups, and
/// a way to create a new one.
///
/// Only ever built when [GroupsController.canUseGroups] is true, so a build
/// without a backend never renders it at all.
class GroupSelector extends StatelessWidget {
  const GroupSelector({super.key, required this.controller});

  final GroupsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final GroupsState state = controller.state;
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: <Widget>[
              ChoiceChip(
                label: Text(l10n.groupsScopePersonal),
                selected: state.selectedGroupId == null,
                onSelected: (_) => controller.select(null),
              ),
              for (final Group group in state.groups) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: Text(group.name),
                  selected: state.selectedGroupId == group.id,
                  onSelected: (_) => controller.select(group.id),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.groupsActionCreate),
                onPressed: () => _createGroup(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              ActionChip(
                avatar: const Icon(Icons.qr_code_rounded, size: 18),
                label: Text(l10n.groupsActionJoin),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const JoinScreen(),
                  ),
                ),
              ),
              if (state.selectedGroupId != null && controller.sync != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _SyncIndicator(controller: controller),
              ],
            ],
          ),
        );
      },
    );
  }

  /// A one-field dialog rather than a whole screen: creating a group is a name
  /// and nothing else.
  ///
  /// The dialog owns its own `TextEditingController` ([_CreateGroupDialog]), so
  /// that controller is only disposed once the dialog's element is gone. A
  /// controller created here and disposed on the line after `showDialog`
  /// returns is torn down while the dialog is still playing its exit
  /// transition and its `TextField` is still mounted — the field then reads a
  /// disposed controller mid-frame, which throws and leaves the element tree
  /// inconsistent (surfacing as a "dirty widget in the wrong build scope"
  /// assertion on the following frame).
  Future<void> _createGroup(BuildContext context) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateGroupDialog(),
    );
    if (result == null) {
      return;
    }
    await controller.createGroup(result);
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
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
