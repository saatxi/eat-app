import 'package:flutter/widgets.dart';

import '../core/app_version.dart';
import '../data/groups/group_gateway.dart';
import '../data/groups/invite_gateway.dart';
import '../data/photo/photo_picker.dart';
import '../data/repositories/restaurant_repository.dart';
import '../data/repositories/user_preferences_repository.dart';
import '../data/supabase/identity.dart';
import '../data/sync/sync_service.dart';
import '../features/groups/groups_controller.dart';

/// Hands the app's long-lived collaborators to any screen that needs them.
///
/// Without a dependency-injection package there is nothing to inject with, so
/// the repositories are built once in `main` and read back through this
/// inherited widget rather than threaded through every constructor between the
/// root and the screen that actually uses them. The [photoPicker] rides along
/// for the same reason: the add/edit and log-visit screens need it, and they sit
/// several routes below the root. A `ChangeNotifierProvider` would be the
/// natural home for this if one were pulled in later; the shape of the lookup
/// (`AppScope.of(context)`) would not change.
///
/// The `PhotoStorage` is deliberately *not* here: only the repository writes and
/// deletes stored photos, so it holds that collaborator itself.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.restaurants,
    required this.preferences,
    required this.photoPicker,
    this.appVersion,
    this.identity,
    this.groups,
    this.invites,
    this.sync,
    this.groupsController,
    required super.child,
  });

  final RestaurantRepository restaurants;
  final UserPreferencesRepository preferences;
  final PhotoPicker photoPicker;

  /// The remote identity behind the shared-groups features. Null in every
  /// mode where groups are off — including every widget test that builds a
  /// bare tree — and every screen must cope with that rather than assume it.
  final IdentityGateway? identity;

  /// The groups backend, and the sync driver that talks to it. Both null
  /// whenever the build carries no Supabase configuration, exactly like
  /// [identity]; personal mode never builds or touches them.
  final GroupGateway? groups;
  final SyncService? sync;

  /// The invitation backend, over the `create-invite` / `join-group` Edge
  /// Functions. Null under the same condition as [groups].
  final InviteGateway? invites;

  /// The one [GroupsController] for the whole app, so the list's selector, the
  /// invite/join screens and a deep link all share the same selection and the
  /// same loaded roster. Null only where the tree is built without one — the
  /// bare widget tests that construct an [AppScope] directly.
  final GroupsController? groupsController;

  /// What the platform reports for the running build, read once at startup.
  /// Null hides the settings screen's About section — the case in a bare widget
  /// test, which has no platform to ask.
  final AppVersion? appVersion;

  static AppScope of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(
      scope != null,
      'No AppScope above this widget — wrap the tree in one.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.restaurants != restaurants ||
      oldWidget.preferences != preferences ||
      oldWidget.photoPicker != photoPicker ||
      oldWidget.appVersion != appVersion ||
      oldWidget.identity != identity ||
      oldWidget.groups != groups ||
      oldWidget.invites != invites ||
      oldWidget.sync != sync ||
      oldWidget.groupsController != groupsController;
}
