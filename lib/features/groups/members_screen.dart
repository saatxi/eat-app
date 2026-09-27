import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/group_models.dart';
import 'members_controller.dart';

/// One group's members: who is in it, an owner's power to remove someone, and
/// everyone's power to leave.
///
/// Reached from the group selector while a group is selected. Leaving clears the
/// selection, so the list falls back to Personal on the way out.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.group});

  final Group group;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MembersController controller = _controller!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: <Widget>[
          TextButton(
            onPressed: _leave,
            child: Text(l10n.groupsActionLeave),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) {
          final MembersState state = controller.state;
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
          final bool iAmOwner =
              widget.group.role == GroupRole.owner;
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
                trailing: iAmOwner && !isMe
                    ? IconButton(
                        onPressed: () => _remove(member),
                        tooltip: l10n.groupsActionRemove,
                        icon: const Icon(Icons.person_remove_outlined),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
