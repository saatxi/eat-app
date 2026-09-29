import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/group_models.dart';
import '../import_export/share_service.dart';
import 'groups_controller.dart';
import 'invite_screen.dart';
import 'members_controller.dart';

/// One group's members, plus what you can do to the group itself: rename it
/// (an owner), export its data, leave it, or (an owner) dissolve it.
///
/// Reached from the group selector while a group is selected. Leaving or
/// dissolving clears the selection, so the list falls back to Personal on the
/// way out.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.group});

  final Group group;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

/// The overflow actions in the app bar.
enum _GroupAction { edit, export, leave, delete }

class _MembersScreenState extends State<MembersScreen> {
  MembersController? _controller;
  bool _loadStarted = false;

  /// The name shown in the app bar, held here so a rename updates it in place
  /// without rebuilding the screen with a fresh [Group].
  late String _groupName = widget.group.name;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppScope scope = AppScope.of(context);
    _controller ??= MembersController(
      groupId: widget.group.id,
      gateway: scope.groups,
      identity: scope.identity,
    );
    if (!_loadStarted) {
      _loadStarted = true;
      unawaited(_controller!.load());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionOk),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<void> _remove(GroupMember member) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!await _confirm(
      l10n.groupsRemoveConfirmTitle,
      l10n.groupsRemoveConfirmBody,
    )) {
      return;
    }
    await _controller?.removeMember(member.userId);
  }

  /// Whether the signed-in user may leave.
  ///
  /// Everyone may, with one exception the server also enforces: the last owner
  /// of a group that still has other members. That owner has to dissolve the
  /// group instead, so the menu offers only that.
  bool _canLeave(MembersState state) {
    if (widget.group.role != GroupRole.owner) {
      return true;
    }
    final int owners = state.members
        .where((GroupMember member) => member.role == GroupRole.owner)
        .length;
    return owners > 1 || state.members.length <= 1;
  }

  Future<void> _leave() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MembersController? controller = _controller;
    final String body = (controller != null &&
            controller.state.members.length <= 1)
        // The last member leaving dissolves the group, so say so before it is
        // done — leaving here deletes the group and its data, not just access.
        ? l10n.groupsLeaveConfirmLastBody
        : l10n.groupsLeaveConfirmBody;
    if (!await _confirm(l10n.groupsLeaveConfirmTitle, body)) {
      return;
    }
    final bool left = await _controller?.leave() ?? false;
    if (!left || !mounted) {
      return;
    }
    await _leaveOrDissolve();
  }

  /// After a successful leave or dissolution, the group is gone from the
  /// remote roster: drop its local rows and (when it was the selected scope)
  /// the selection, tell the shared [GroupsController] to reload so the group
  /// disappears from the list, then pop back.
  ///
  /// The remote cascades the group's rows away, so nothing arrives to clean the
  /// local copies up — and clearing the selection only when this really was the
  /// selected group keeps a different scope intact for a user who was managing
  /// another one.
  Future<void> _leaveOrDissolve() async {
    final AppScope scope = AppScope.of(context);
    await scope.restaurants.purgeGroup(widget.group.id);
    if (scope.preferences.current.selectedGroupId == widget.group.id) {
      await scope.preferences.setSelectedGroup(null);
    }
    final GroupsController? controller = scope.groupsController;
    if (controller != null) {
      await controller.load();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteGroup() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!await _confirm(
      l10n.groupsDeleteConfirmTitle,
      l10n.groupsDeleteConfirmBody,
    )) {
      return;
    }
    final bool deleted = await _controller?.deleteGroup() ?? false;
    if (!deleted || !mounted) {
      return;
    }
    await _leaveOrDissolve();
  }

  /// Renames the group. Only an owner may — the `groups_update_owner` policy
  /// enforces it server-side, and the menu offers it to an owner alone.
  Future<void> _editGroup() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppScope scope = AppScope.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _EditGroupDialog(initialName: _groupName),
    );
    if (newName == null || newName == _groupName) {
      return;
    }
    final groups = scope.groups;
    if (groups == null) {
      return;
    }
    try {
      await groups.editGroup(widget.group.id, newName);
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupsEditErrorFailed)),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _groupName = newName);
    // Keep the shared list in step, so the renamed group shows its new name
    // once this screen is popped.
    await scope.groupsController?.load();
  }

  /// The safety net before a leave or a dissolution: this group's restaurants
  /// (and their visits) as a file the user keeps.
  Future<void> _exportGroup() => exportAndShareRestaurants(
    context,
    repository: AppScope.of(context).restaurants,
    groupName: _groupName,
    groupId: widget.group.id,
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MembersController controller = _controller!;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final MembersState state = controller.state;
        final bool iAmOwner = widget.group.role == GroupRole.owner;
        return Scaffold(
          appBar: AppBar(
            title: Text(_groupName),
            actions: <Widget>[
              // Only an owner may invite, and the create-invite function
              // re-checks it server-side.
              if (iAmOwner)
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          InviteScreen(group: widget.group),
                    ),
                  ),
                  tooltip: l10n.groupsInviteAction,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              PopupMenuButton<_GroupAction>(
                tooltip: l10n.groupsActionMore,
                onSelected: (_GroupAction action) {
                  switch (action) {
                    case _GroupAction.edit:
                      unawaited(_editGroup());
                    case _GroupAction.export:
                      unawaited(_exportGroup());
                    case _GroupAction.leave:
                      unawaited(_leave());
                    case _GroupAction.delete:
                      unawaited(_deleteGroup());
                  }
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_GroupAction>>[
                      if (iAmOwner)
                        PopupMenuItem<_GroupAction>(
                          value: _GroupAction.edit,
                          child: Text(l10n.groupsEditTitle),
                        ),
                      PopupMenuItem<_GroupAction>(
                        value: _GroupAction.export,
                        child: Text(l10n.groupsActionExport),
                      ),
                      if (_canLeave(state))
                        PopupMenuItem<_GroupAction>(
                          value: _GroupAction.leave,
                          child: Text(l10n.groupsActionLeave),
                        ),
                      if (iAmOwner)
                        PopupMenuItem<_GroupAction>(
                          value: _GroupAction.delete,
                          child: Text(l10n.groupsActionDelete),
                        ),
                    ],
              ),
            ],
          ),
          body: _body(l10n, state, iAmOwner),
        );
      },
    );
  }

  Widget _body(AppLocalizations l10n, MembersState state, bool iAmOwner) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(l10n.groupsMembersError),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: state.members.length,
      itemBuilder: (BuildContext context, int index) {
        final GroupMember member = state.members[index];
        final bool isMe = member.userId == state.currentUserId;
        final String name =
            member.displayName.isEmpty ? member.userId : member.displayName;
        // The name is purely informational: changing your display name is done
        // from the groups list ("Change your name"), never from a member row.
        // Everyone else's row belongs to an owner to remove.
        return ListTile(
          leading: CircleAvatar(
            child: Text(name.substring(0, 1).toUpperCase()),
          ),
          title: Text(isMe ? '${l10n.groupsMemberYou} · $name' : name),
          subtitle: member.role == GroupRole.owner
              ? Text(l10n.groupsMemberOwner)
              : null,
          trailing: !isMe && iAmOwner
              ? IconButton(
                  onPressed: () => _remove(member),
                  tooltip: l10n.groupsActionRemove,
                  icon: const Icon(Icons.person_remove_outlined),
                )
              : null,
        );
      },
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
