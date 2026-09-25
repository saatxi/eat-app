import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_scope.dart';
import 'core/l10n/app_language.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'data/db/app_database.dart';
import 'data/migration/room_to_drift_importer.dart';
import 'data/repositories/restaurant_repository.dart';
import 'data/repositories/user_preferences_repository.dart';
import 'data/share/backup_writer.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The preference file is read before the first frame rather than asynchronously
  // afterwards: the palette, the light/dark choice and the language all decide
  // what that first frame looks like, and starting on the defaults and swapping
  // them out afterwards would be a visible flash on every launch.
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  // Opened eagerly so the Room→drift import can finish before anything tries to
  // read a restaurant — including the home-screen widget, which runs in its own
  // isolate and would otherwise race this.
  final AppDatabase database = AppDatabase(openAppDatabase());
  await RoomToDriftImporter(
    database: database,
    locator: const RoomDatabaseFileLocator(),
    preferences: preferences,
  ).run();

  runApp(
    EatApp(
      preferences: UserPreferencesRepository(store: preferences),
      // The on-device snapshot is written after every change, so a device
      // restore brings the data along without the user ever pressing export.
      repository: RestaurantRepository(
        database,
        backupWriter: const FileBackupWriter(),
      ),
    ),
  );
}

/// The application root.
///
/// It publishes the two repositories through an [AppScope], selects between the
/// light and dark `ThemeData` the token layer builds, wires up localization and
/// hands the tree its [HomeShell]. Routing itself lives in the shell.
class EatApp extends StatefulWidget {
  const EatApp({super.key, this.preferences, this.repository});

  /// Null in tests and previews, where an in-memory repository keeps the widget
  /// free of any plugin dependency.
  final UserPreferencesRepository? preferences;

  /// Likewise null in tests and previews, where an in-memory database stands in
  /// for the file-backed one.
  final RestaurantRepository? repository;

  @override
  State<EatApp> createState() => _EatAppState();
}

class _EatAppState extends State<EatApp> {
  late final UserPreferencesRepository _preferences =
      widget.preferences ?? UserPreferencesRepository();

  late final RestaurantRepository _repository =
      widget.repository ?? RestaurantRepository(AppDatabase.memory());

  /// Resolves the device's preferred language to one we ship, falling back to
  /// English — without this, Flutter's default resolution picks the first
  /// supported locale (Catalan, alphabetically) for a device in a language we
  /// don't translate.
  static Locale _resolveLocale(
    List<Locale>? locales,
    Iterable<Locale> supportedLocales,
  ) {
    for (final Locale locale in locales ?? const <Locale>[]) {
      final AppLanguage? match = AppLanguage.resolveDeviceLocale(locale);
      if (match != null) {
        return match.locale;
      }
    }
    return AppLanguage.fallback.locale;
  }

  @override
  Widget build(BuildContext context) {
    // The scope sits above MaterialApp so every pushed route can reach it, not
    // just the initial one.
    return AppScope(
      restaurants: _repository,
      preferences: _preferences,
      // Rebuilding from the repository rather than from local state is what makes
      // a change survive the widget being recreated, and what lets every stored
      // value be the single source of truth for what is on screen.
      child: ValueListenableBuilder<UserPreferences>(
        valueListenable: _preferences.listenable,
        builder: (BuildContext context, UserPreferences preferences, _) {
          final AppLanguage? language = preferences.language;
          return MaterialApp(
            onGenerateTitle: (BuildContext context) =>
                AppLocalizations.of(context).appName,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Null until the user picks one explicitly, so a fresh install
            // follows the device's language.
            locale: language?.locale,
            localeListResolutionCallback: _resolveLocale,
            // Both brightnesses are provided so Flutter can cross-fade between
            // them when the mode changes, instead of swapping the tree's theme
            // outright.
            theme: AppTheme.of(
              palette: preferences.palette,
              mode: AppThemeMode.light,
            ),
            darkTheme: AppTheme.of(
              palette: preferences.palette,
              mode: AppThemeMode.dark,
            ),
            themeMode: preferences.themeMode.brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
