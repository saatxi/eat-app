import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/group_models.dart';
import '../import_export/share_service.dart';
import 'invite_screen.dart';
import 'members_controller.dart';

/// One group's members, plus the three things you can do to the group itself:
/// export its data, leave it, or (an owner) dissolve it.
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
enum _GroupAction { export, leave, delete }

class _MembersScreenState extends State<MembersScreen> {
  MembersController? _controller;
  bool _loadStarted = false;

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

  /// Lets the signed-in user give themselves a display name, so the roster
  /// shows a name instead of the bare user id a fresh anonymous account has.
  Future<void> _renameMe(GroupMember member) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _RenameDialog(initialName: member.displayName),
    );
    if (name == null) {
      return;
    }
    final MembersController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (!await controller.setDisplayName(name)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupsNameErrorFailed)),
      );
    }
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
    if (!await _confirm(
      l10n.groupsLeaveConfirmTitle,
      l10n.groupsLeaveConfirmBody,
    )) {
      return;
    }
    final bool left = await _controller?.leave() ?? false;
    if (!left || !mounted) {
      return;
    }
    // Back to Personal: the group is no longer one the list can show.
    await AppScope.of(context).preferences.setSelectedGroup(null);
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
    await AppScope.of(context).preferences.setSelectedGroup(null);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// The safety net before a leave or a dissolution: this group's restaurants
  /// (and their visits) as a file the user keeps.
  Future<void> _exportGroup() => exportAndShareRestaurants(
    context,
    repository: AppScope.of(context).restaurants,
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
            title: Text(widget.group.name),
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
        return ListTile(
          leading: CircleAvatar(
            child: Text(name.substring(0, 1).toUpperCase()),
          ),
          title: Text(isMe ? '${l10n.groupsMemberYou} · $name' : name),
          subtitle: member.role == GroupRole.owner
              ? Text(l10n.groupsMemberOwner)
              : null,
          // Your own row is the one place your name is shown, so it is also
          // where it can be changed; everyone else is an owner's to remove.
          onTap: isMe ? () => _renameMe(member) : null,
          trailing: isMe
              ? IconButton(
                  onPressed: () => _renameMe(member),
                  tooltip: l10n.groupsNameEditAction,
                  icon: const Icon(Icons.edit_outlined),
                )
              : iAmOwner
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

/// The "change your name" dialog: one field and the two actions.
///
/// A [StatefulWidget] purely so it can own the field's [TextEditingController]
/// and dispose it when the dialog itself is torn down, rather than leaving the
/// caller to guess when the route has finished animating away.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  /// The name the field opens on; empty for an account that has never set one.
  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _name.text.trim();
    if (value.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).groupsNameRequired);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.groupsNameDialogTitle),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: l10n.groupsNameFieldLabel,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionOk)),
      ],
    );
  }
}
