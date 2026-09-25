import 'package:flutter/widgets.dart';

import '../data/repositories/restaurant_repository.dart';
import '../data/repositories/user_preferences_repository.dart';

/// Hands the app's two long-lived collaborators to any screen that needs them.
///
/// Without a dependency-injection package there is nothing to inject with, so
/// the repositories are built once in `main` and read back through this
/// inherited widget rather than threaded through every constructor between the
/// root and the screen that actually uses them. A `ChangeNotifierProvider` would
/// be the natural home for this if one were pulled in later; the shape of the
/// lookup (`AppScope.of(context)`) would not change.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.restaurants,
    required this.preferences,
    required super.child,
  });

  final RestaurantRepository restaurants;
  final UserPreferencesRepository preferences;

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
      oldWidget.preferences != preferences;
}
