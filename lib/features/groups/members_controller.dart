import 'package:flutter/foundation.dart';

import '../../data/groups/group_gateway.dart';
import '../../data/groups/group_models.dart';
import '../../data/supabase/identity.dart';

/// One group's roster, as the members screen draws it.
@immutable
class MembersState {
  const MembersState({
    this.members = const <GroupMember>[],
    this.currentUserId,
    this.isLoading = true,
    this.error,
  });

  final List<GroupMember> members;

  /// The signed-in user's id, so the row can mark "you" and decide what an owner
  /// may do to whom.
  final String? currentUserId;

  final bool isLoading;
  final Object? error;
}

/// Loads one group's members and performs the two membership actions: an owner
/// removing someone, and anyone leaving.
class MembersController extends ChangeNotifier {
  MembersController({
    required this.groupId,
    this.gateway,
    this.identity,
  });

  final String groupId;
  final GroupGateway? gateway;
  final IdentityGateway? identity;

  MembersState _state = const MembersState();
  bool _disposed = false;

  MembersState get state => _state;

  Future<void> load() async {
    final GroupGateway? groups = gateway;
    if (groups == null) {
      _set(const MembersState(isLoading: false));
      return;
    }
    _set(
      MembersState(
        members: _state.members,
        currentUserId: _state.currentUserId,
        isLoading: true,
      ),
    );
    try {
      final Identity? me = await identity?.current();
      final List<GroupMember> members = await groups.listMembers(groupId);
      _set(
        MembersState(
          members: members,
          currentUserId: me?.userId,
          isLoading: false,
        ),
      );
    } catch (error) {
      _set(
        MembersState(
          currentUserId: _state.currentUserId,
          isLoading: false,
          error: error,
        ),
      );
    }
  }

  /// An owner removes another member. Returns whether it worked.
  Future<bool> removeMember(String userId) =>
      _mutate(() => gateway!.removeMember(groupId, userId));

  /// An owner dissolves the group entirely. Returns whether it worked.
  Future<bool> deleteGroup() =>
      _mutate(() => gateway!.deleteGroup(groupId));

  /// The signed-in user leaves the group. Returns whether it worked.
  Future<bool> leave() async {
    final String? me =
        _state.currentUserId ?? (await identity?.current())?.userId;
    if (me == null || gateway == null) {
      return false;
    }
    return _mutate(() => gateway!.leaveGroup(groupId, me));
  }

  /// Sets the signed-in user's own display name, so the roster shows a name
  /// instead of their user id, then reloads so the row updates. Returns whether
  /// it worked.
  Future<bool> setDisplayName(String name) async {
    final String? me =
        _state.currentUserId ?? (await identity?.current())?.userId;
    if (me == null || gateway == null) {
      return false;
    }
    return _mutate(
      () => gateway!.setDisplayName(userId: me, displayName: name),
    );
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return true;
    } catch (error) {
      _set(
        MembersState(
          members: _state.members,
          currentUserId: _state.currentUserId,
          isLoading: false,
          error: error,
        ),
      );
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _set(MembersState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}
