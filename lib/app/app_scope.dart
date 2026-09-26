import 'package:flutter/widgets.dart';

import '../core/app_version.dart';
import '../data/photo/photo_picker.dart';
import '../data/repositories/restaurant_repository.dart';
import '../data/repositories/user_preferences_repository.dart';

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
    required super.child,
  });

  final RestaurantRepository restaurants;
  final UserPreferencesRepository preferences;
  final PhotoPicker photoPicker;

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
      oldWidget.appVersion != appVersion;
}
