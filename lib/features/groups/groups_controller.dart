import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/groups/group_gateway.dart';
import '../../data/groups/group_models.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../data/supabase/identity.dart';
import '../../data/sync/sync_service.dart';

/// The user's groups and which one is selected, as the selector and the members
/// screen read them.
@immutable
class GroupsState {
  const GroupsState({
    this.groups = const <Group>[],
    this.selectedGroupId,
    this.isLoading = true,
    this.error,
    this.ownerGroupLimit,
  });

  final List<Group> groups;

  /// Null means Personal.
  final String? selectedGroupId;

  /// True until the first load answers — or forever, when there is no backend.
  final bool isLoading;

  /// The last load/create failure, for the UI to surface. Null once a load
  /// succeeds.
  final Object? error;

  /// How many groups one user may own, per the backend. Null until the first
  /// successful load (or forever when groups are off), meaning "unknown — the
  /// backend decides"; never treat null as unlimited.
  final int? ownerGroupLimit;

  /// How many of the current groups the signed-in user owns.
  int get ownedGroupsCount =>
      groups.where((Group group) => group.role == GroupRole.owner).length;

  /// Whether creating another group would exceed the owner cap. Null limit
  /// (no backend, or not loaded yet) reads as false — the server still
  /// enforces the cap either way.
  bool get ownerCapReached {
    final int? limit = ownerGroupLimit;
    return limit != null && ownedGroupsCount >= limit;
  }

  /// The selected group, or null for Personal (or a selection that no longer
  /// exists, which reads as Personal).
  Group? get selected {
    for (final Group group in groups) {
      if (group.id == selectedGroupId) {
        return group;
      }
    }
    return null;
  }
}

/// Loads the signed-in user's groups and keeps the selection in step with the
/// persisted preference.
///
/// A null [gateway] or [identity] — every build without Supabase configuration,
/// and every bare test — leaves it empty and idle: [canUseGroups] is false and
/// the selector offers nothing but Personal. That keeps personal mode free of
/// any group surface.
class GroupsController extends ChangeNotifier {
  GroupsController({
    required this.preferences,
    this.gateway,
    this.identity,
    this.sync,
  }) {
    _selectedGroupId = preferences.current.selectedGroupId;
    preferences.listenable.addListener(_onPreferencesChanged);
    unawaited(load());
  }

  final UserPreferencesRepository preferences;
  final GroupGateway? gateway;
  final IdentityGateway? identity;

  /// The sync driver, when the build has one. Selecting a group (and loading a
  /// selection that already existed) kicks a sync through it.
  final SyncService? sync;

  static const Uuid _uuid = Uuid();

  GroupsState _state = const GroupsState();
  String? _selectedGroupId;
  bool _disposed = false;

  GroupsState get state => _state;

  /// Whether there is a backend to talk to at all. False hides every group
  /// affordance.
  bool get canUseGroups => gateway != null && identity != null;

  /// Reads the user's memberships. Signs nobody in — a device that has never
  /// signed in simply has no groups yet.
  Future<void> load() async {
    final GroupGateway? groups = gateway;
    final IdentityGateway? account = identity;
    if (groups == null || account == null) {
      _setState(GroupsState(selectedGroupId: _selectedGroupId, isLoading: false));
      return;
    }

    _setState(
      GroupsState(
        groups: _state.groups,
        selectedGroupId: _selectedGroupId,
        isLoading: true,
      ),
    );
    try {
      final Identity? me = await _withTimeout(
        account.current(),
        Duration(seconds: 10),
        'Identity check timed out',
      );
      final List<Group> loaded = me == null
          ? const <Group>[]
          : await _withTimeout(
              groups.listGroups(me.userId),
              Duration(seconds: 10),
              'Group list timed out',
            );
      // The owner cap tells the create button whether it can still be offered.
      // A failure to read it must not fail the whole load; unknown means the
      // server stays the authority (and the button stays enabled).
      int? limit;
      try {
        limit = await groups.ownerGroupLimit();
      } catch (error, stackTrace) {
        debugPrint('Reading the owner group limit failed: $error');
        if (kDebugMode) {
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      _setState(
        GroupsState(
          selectedGroupId: _selectedGroupId,
          groups: loaded,
          isLoading: false,
          ownerGroupLimit: limit,
        ),
      );
      _syncSelected();
    } catch (error) {
      _setState(
        GroupsState(
          selectedGroupId: _selectedGroupId,
          isLoading: false,
          error: error,
        ),
      );
    }
  }

  /// Selects a scope (a group id, or null for Personal) and persists it. The
  /// list, stats and roulette controllers all react to the preference change,
  /// and selecting a group pulls it once so the list has fresh rows.
  Future<void> select(String? groupId) async {
    await preferences.setSelectedGroup(groupId);
    await syncNow();
  }

  /// Pushes and pulls the selected group now, if there is one to sync and a
  /// service to do it. [SyncService] records the outcome on its own notifier
  /// rather than throwing, so callers can fire and forget.
  Future<void> syncNow() async {
    final SyncService? service = sync;
    final String? groupId = _selectedGroupId;
    if (service == null || groupId == null) {
      return;
    }
    await service.syncGroup(groupId);
  }

  void _syncSelected() => unawaited(syncNow());

  /// Edits [groupId]'s name. Only an owner may call this; RLS enforces it
  /// server-side. Returns whether it worked; a failure lands in
  /// [GroupsState.error].
  Future<bool> editGroup(String groupId, String name) async {
    final GroupGateway? groups = gateway;
    if (groups == null) {
      return false;
    }
    try {
      await groups.editGroup(groupId, name);
      await load();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Editing a group failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      _setState(
        GroupsState(
          groups: _state.groups,
          selectedGroupId: _selectedGroupId,
          isLoading: false,
          error: error,
        ),
      );
      return false;
    }
  }

  /// Creates a group — signing in anonymously first when the device has never
  /// signed in, since a group needs an owner — then selects it. Returns whether
  /// it worked; a failure lands in [GroupsState.error].
  Future<bool> createGroup(String name) async {
    final GroupGateway? groups = gateway;
    final IdentityGateway? account = identity;
    if (groups == null || account == null) {
      return false;
    }
    try {
      final Identity me = (await account.current()) ??
          await account.signInAnonymously();
      final Group created = await groups.createGroup(
        id: _uuid.v4(),
        name: name,
        createdBy: me.userId,
      );
      await load();
      await select(created.id);
      return true;
    } catch (error, stackTrace) {
      // The UI can only offer "try again", so the actual cause — a lost or
      // refused session, no network, a policy rejection — is logged where a
      // developer can see it.
      debugPrint('Creating a group failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      _setState(
        GroupsState(
          groups: _state.groups,
          selectedGroupId: _selectedGroupId,
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
    preferences.listenable.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  void _onPreferencesChanged() {
    final String? next = preferences.current.selectedGroupId;
    if (next == _selectedGroupId) {
      return;
    }
    _selectedGroupId = next;
    _setState(
      GroupsState(
        groups: _state.groups,
        selectedGroupId: next,
        isLoading: _state.isLoading,
        error: _state.error,
      ),
    );
  }

  static Future<T> _withTimeout<T>(Future<T> future, Duration timeout, String message) async {
    return await future.timeout(timeout, onTimeout: () async => throw TimeoutException(message));
  }

  void _setState(GroupsState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}
