import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n/app_language.dart';
import '../core/l10n/generated/app_localizations.dart';
import '../data/db/app_database.dart';
import '../data/repositories/restaurant_repository.dart';
import '../data/repositories/user_preferences_repository.dart';
import 'home_widget_snapshot.dart';

/// The iOS App Group the app and the widget extension share.
///
/// Has to be identical in three places — here, `ios/Runner/Runner.entitlements`
/// and `ios/EatAppWidget/EatAppWidget.entitlements` — because that group is the
/// only channel between them; see `docs/ios-widget.md`.
const String homeWidgetAppGroupId = 'group.com.saatxi.eatapp';

/// The Android provider the widget data is published to, fully qualified so the
/// plugin resolves it without guessing. Matches the `<receiver>` in
/// `android/app/src/main/AndroidManifest.xml`.
const String _androidProviderName = 'com.saatxi.eatapp.EatAppHomeWidgetProvider';

/// The iOS widget's `kind`, which has to match the `kind` its Swift
/// `StaticConfiguration` is built with, in `ios/EatAppWidget/EatAppWidget.swift`.
const String _iOSWidgetKind = 'EatAppWidget';

/// The service the background callback reuses for the life of its isolate.
///
/// Built once and kept, rather than rebuilt per invocation: the plugin runs the
/// callback on one long-lived headless engine, so a fresh [AppDatabase] each
/// time would open a new SQLite connection on every shuffle and never close
/// one.
HomeWidgetService? _backgroundService;

/// The entry point the widget's shuffle button runs in the background.
///
/// Must be a top-level function with the `vm:entry-point` pragma: the plugin
/// launches a second Flutter engine for it, in its own isolate, and can only
/// find the callback by name. It therefore builds the database and repositories
/// it needs rather than reaching into the running app's.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  final HomeWidgetService service =
      _backgroundService ??= await _openBackgroundService();
  await service.refresh(pickNew: uri?.host == 'shuffle');
}

Future<HomeWidgetService> _openBackgroundService() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  return HomeWidgetService(
    // No backup writer and no photo storage: this only reads, and neither of
    // those ever runs unless something is written.
    repository: RestaurantRepository(AppDatabase(openAppDatabase())),
    preferences: UserPreferencesRepository(store: preferences),
  );
}

/// Keeps the home-screen widget's data in step with the app's.
///
/// The Android provider and the WidgetKit extension are both dumb renderers:
/// this is the only place that knows what a "want to try" restaurant is, how to
/// translate a cuisine and when the widget should redraw.
class HomeWidgetService {
  HomeWidgetService({required this.repository, required this.preferences});

  final RestaurantRepository repository;
  final UserPreferencesRepository preferences;

  /// Republishes the widget's data.
  ///
  /// Called once at startup — so a widget already on the home screen picks up
  /// whatever the Room→drift import just brought over — after every write the
  /// repository makes, and by the background callback behind the shuffle
  /// button.
  ///
  /// [pickNew] forces a fresh random pick, which is the shuffle button's job.
  /// Otherwise the restaurant already on the widget is kept while it is still
  /// want-to-try, so editing some *other* restaurant doesn't flip the card to
  /// somebody else's.
  ///
  /// Deliberately swallows its own failures: this hangs off both app startup and
  /// every write, and a widget that can't redraw — a platform channel error, a
  /// device where no widget was ever added — must not take either down. The next
  /// refresh picks up whatever was missed.
  Future<void> refresh({bool pickNew = false}) async {
    try {
      final AppLocalizations l10n = lookupAppLocalizations(_language().locale);
      final HomeWidgetSnapshot snapshot = buildHomeWidgetSnapshot(
        restaurant: await _pick(pickNew: pickNew),
        l10n: l10n,
      );

      await HomeWidget.saveWidgetData<String>(
        HomeWidgetKeys.restaurantId,
        snapshot.restaurantId,
      );
      await HomeWidget.saveWidgetData<String>(
        HomeWidgetKeys.title,
        snapshot.title,
      );
      await HomeWidget.saveWidgetData<String>(
        HomeWidgetKeys.subtitle,
        snapshot.subtitle,
      );

      // The static labels ride along with the data so the widget can be
      // translated without a native string per language: Dart knows the language
      // in force, the native side only knows how to draw what it is handed. It
      // also keeps the three locales in one place (the ARB files) rather than
      // splitting them across `values-*` and a `.strings` catalog.
      await HomeWidget.saveWidgetData<String>(
        HomeWidgetKeys.label,
        l10n.widgetLabel,
      );
      await HomeWidget.saveWidgetData<String>(
        HomeWidgetKeys.empty,
        l10n.widgetEmptyBody,
      );
      await HomeWidget.saveWidgetData<String>(
        HomeWidgetKeys.shuffle,
        l10n.widgetActionShuffle,
      );

      await HomeWidget.updateWidget(
        qualifiedAndroidName: _androidProviderName,
        iOSName: _iOSWidgetKind,
      );
    } catch (error, stackTrace) {
      debugPrint('Home-screen widget refresh failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  /// The restaurant the widget should show: the one already saved while it is
  /// still want-to-try, or a fresh random one.
  Future<Restaurant?> _pick({required bool pickNew}) async {
    if (!pickNew) {
      final String? currentId = await HomeWidget.getWidgetData<String>(
        HomeWidgetKeys.restaurantId,
      );
      if (currentId != null && currentId.isNotEmpty) {
        final Restaurant? current = await repository
            .observeById(currentId)
            .first;
        // A restaurant stops being want-to-try the moment it gets a visit, so
        // the latest visit is the whole test — the same one the list's
        // want-to-try filter uses.
        if (current != null &&
            await repository.getLatestVisit(current.id) == null) {
          return current;
        }
      }
    }
    return repository.getRandomWantToTry();
  }

  /// The language to draw the widget's labels in: the user's explicit choice,
  /// or — when they have never picked one, so the app follows the device — the
  /// best of the device's own languages.
  AppLanguage _language() {
    final AppLanguage? chosen = preferences.current.language;
    if (chosen != null) {
      return chosen;
    }
    for (final Locale locale
        in WidgetsBinding.instance.platformDispatcher.locales) {
      final AppLanguage? match = AppLanguage.resolveDeviceLocale(locale);
      if (match != null) {
        return match;
      }
    }
    return AppLanguage.fallback;
  }
}
