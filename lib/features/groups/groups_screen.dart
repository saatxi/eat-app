import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/group_models.dart';
import '../../data/sync/sync_service.dart';
import 'groups_controller.dart';
import 'invite_screen.dart';
import 'join_screen.dart';
import 'members_screen.dart';

/// The Groups half of the app: a list of every group the signed-in user belongs
/// to, with actions to create, join, edit, leave and dissolve groups, plus one-
/// tap access to members and invitations.
///
/// Only shown when [GroupsController.canUseGroups] is true (the build carries
/// Supabase configuration). When groups are unavailable the tab that leads here
/// is hidden entirely.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    final GroupsController? controller = scope.groupsController;
    if (controller == null || !controller.canUseGroups) {
      // Personal mode — no groups backend configured.
      return const Scaffold(
        body: Center(child: Text('Groups require the shared backend.')),
      );
    }
    return _GroupsScreenBody(controller: controller);
  }
}

class _GroupsScreenBody extends StatefulWidget {
  const _GroupsScreenBody({required this.controller});

  final GroupsController controller;

  @override
  State<_GroupsScreenBody> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<_GroupsScreenBody> {
  // No explicit load needed: the controller created in main.dart initState
  // already calls load() eagerly, so the screen only needs to observe via
  // ListenableBuilder.

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
    if (!await widget.controller.createGroup(result)) {
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

  void _openInvite(BuildContext context, Group group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => InviteScreen(group: group),
      ),
    );
  }

  Future<void> _editName(BuildContext context, Group group) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _EditGroupDialog(initialName: group.name),
    );
    if (newName == null || newName == group.name) {
      return;
    }
    if (!await widget.controller.editGroup(group.id, newName)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupsEditErrorFailed)),
      );
    }
  }

  Future<void> _leaveGroup(BuildContext context, Group group) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.groupsLeaveConfirmTitle),
        content: Text(l10n.groupsLeaveConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionOk),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      // Leave is done through the MembersScreen's gateway, but we can also
      // call it directly since GroupsController exposes the gateway.
      final gateway = widget.controller.gateway;
      if (gateway != null && widget.controller.state.selectedGroupId != null) {
        // We need the current user id — use the identity gateway.
        final identity = widget.controller.identity;
        final currentUserId = (await identity?.current())?.userId;
        if (currentUserId != null) {
          await gateway.leaveGroup(group.id, currentUserId);
          await widget.controller.load();
        }
      }
    }
  }

  Future<void> _deleteGroup(BuildContext context, Group group) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.groupsDeleteConfirmTitle),
        content: Text(l10n.groupsDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final gateway = widget.controller.gateway;
      if (gateway != null) {
        await gateway.deleteGroup(group.id);
        await widget.controller.load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navGroups)),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (BuildContext context, Widget? child) {
          final GroupsState state = widget.controller.state;
          if (state.isLoading && state.groups.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: <Widget>[
              for (final Group group in state.groups)
                _GroupTile(
                  group: group,
                  syncStatus: widget.controller.sync?.status.value,
                  onOpenMembers: () => _openMembers(context, group),
                  onOpenInvite: () => _openInvite(context, group),
                  onEditName: () => _editName(context, group),
                  onLeave: () => _leaveGroup(context, group),
                  onDelete: () => _deleteGroup(context, group),
                ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner_rounded),
                title: Text(l10n.groupsActionJoin),
                onTap: () => _join(context),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FilledButton.icon(
        onPressed: () => _createGroup(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.groupsActionCreate),
      ),
    );
  }
}

/// A single group row in the list: name, role indicator, sync status, trailing
/// actions.
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    this.syncStatus,
    required this.onOpenMembers,
    required this.onOpenInvite,
    required this.onEditName,
    required this.onLeave,
    required this.onDelete,
  });

  final Group group;
  final SyncStatus? syncStatus;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenInvite;
  final VoidCallback onEditName;
  final VoidCallback onLeave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color surfaceVariant = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
      child: InkWell(
        onTap: onOpenMembers,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Row(
            children: <Widget>[
              // Role indicator dot.
              CircleAvatar(
                radius: 4,
                backgroundColor: group.role == GroupRole.owner
                    ? primary
                    : primary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Text(
                          group.role == GroupRole.owner
                              ? AppLocalizations.of(context).groupsMemberOwner
                              : AppLocalizations.of(context).groupsMemberYou,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (syncStatus != null) ...<Widget>[
                          const SizedBox(width: 8),
                          _SyncDot(status: syncStatus!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Trailing actions.
              IconButton(
                onPressed: onOpenMembers,
                tooltip: AppLocalizations.of(context).groupsMembersTitle,
                icon: const Icon(Icons.people_outline),
              ),
              if (group.role == GroupRole.owner)
                IconButton(
                  onPressed: onOpenInvite,
                  tooltip: AppLocalizations.of(context).groupsInviteAction,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              PopupMenuButton<String>(
                tooltip: AppLocalizations.of(context).groupsActionMore,
                onSelected: (String action) {
                  switch (action) {
                    case 'edit':
                      onEditName();
                    case 'leave':
                      onLeave();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(AppLocalizations.of(context).groupsEditTitle),
                  ),
                  PopupMenuItem<String>(
                    value: 'leave',
                    child: Text(
                      AppLocalizations.of(context).groupsActionLeave,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  if (group.role == GroupRole.owner)
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        AppLocalizations.of(context).groupsActionDelete,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small sync status dot next to the group name.
class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (status) {
      case SyncStatus.syncing:
        icon = Icons.circle;
        color = Theme.of(context).colorScheme.primary;
      case SyncStatus.succeeded:
        icon = Icons.check_circle;
        color = Theme.of(context).colorScheme.primary;
      case SyncStatus.failed:
        icon = Icons.error;
        color = Theme.of(context).colorScheme.error;
      case SyncStatus.idle:
        icon = Icons.circle_outlined;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return Icon(icon, size: 12, color: color);
  }
}

/// The "create a group" dialog: one name field and its two actions.
class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  late final TextEditingController _name = TextEditingController();

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

/// The "edit group name" dialog: one pre-filled name field and its two actions.
class _EditGroupDialog extends StatefulWidget {
  const _EditGroupDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
  }

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
      title: Text(l10n.groupsEditTitle),
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
        FilledButton(onPressed: _submit, child: Text(l10n.groupsEditAction)),
      ],
    );
  }
}
