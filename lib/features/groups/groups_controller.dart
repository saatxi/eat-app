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
  });

  final List<Group> groups;

  /// Null means Personal.
  final String? selectedGroupId;

  /// True until the first load answers — or forever, when there is no backend.
  final bool isLoading;

  /// The last load/create failure, for the UI to surface. Null once a load
  /// succeeds.
  final Object? error;

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
      final Identity? me = await account.current();
      final List<Group> loaded = me == null
          ? const <Group>[]
          : await groups.listGroups(me.userId);
      _setState(
        GroupsState(selectedGroupId: _selectedGroupId, groups: loaded),
      );
      _syncSelected();
    } catch (error) {
      _setState(
        GroupsState(selectedGroupId: _selectedGroupId, error: error),
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

  void _setState(GroupsState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}
