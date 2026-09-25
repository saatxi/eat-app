import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n/app_language.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'core/theme/theme_gallery.dart';
import 'data/db/app_database.dart';
import 'data/migration/room_to_drift_importer.dart';
import 'data/repositories/user_preferences_repository.dart';

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

  runApp(EatApp(preferences: UserPreferencesRepository(store: preferences)));
}

/// The application root.
///
/// At this stage it selects between the light and dark `ThemeData` the token
/// layer builds, wires up localization, and shows the token gallery so the
/// design system is visible before any real screen exists. Routing arrives in a
/// later block; the palette, theme mode and language already persist.
class EatApp extends StatefulWidget {
  const EatApp({super.key, this.preferences});

  /// Null in tests and previews, where an in-memory repository keeps the widget
  /// free of any plugin dependency.
  final UserPreferencesRepository? preferences;

  @override
  State<EatApp> createState() => _EatAppState();
}

class _EatAppState extends State<EatApp> {
  late final UserPreferencesRepository _preferences =
      widget.preferences ?? UserPreferencesRepository();

  void _setPalette(AppPalette palette) {
    _preferences.setPalette(palette);
  }

  void _setMode(AppThemeMode mode) {
    _preferences.setThemeMode(mode);
  }

  void _setLanguage(AppLanguage? language) {
    _preferences.setLanguage(language);
  }

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
    // Rebuilding from the repository rather than from local state is what makes
    // a change survive the widget being recreated, and what lets every stored
    // value be the single source of truth for what is on screen.
    return ValueListenableBuilder<UserPreferences>(
      valueListenable: _preferences.listenable,
      builder: (BuildContext context, UserPreferences preferences, _) {
        final AppLanguage? language = preferences.language;
        return MaterialApp(
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context).appName,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Null until the user picks one explicitly, so a fresh install follows
          // the device's language.
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
          home: ThemeGallery(
            palette: preferences.palette,
            mode: preferences.themeMode,
            language: language,
            onPaletteChanged: _setPalette,
            onModeChanged: _setMode,
            onLanguageChanged: _setLanguage,
          ),
        );
      },
    );
  }
}
