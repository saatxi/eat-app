import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_scope.dart';
import 'core/app_version.dart';
import 'core/l10n/app_language.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'data/db/app_database.dart';
import 'data/migration/room_to_drift_importer.dart';
import 'data/photo/image_picker_photo_picker.dart';
import 'data/photo/photo_picker.dart';
import 'data/photo/photo_storage.dart';
import 'data/repositories/restaurant_repository.dart';
import 'data/repositories/user_preferences_repository.dart';
import 'data/share/backup_writer.dart';
import 'features/home/home_shell.dart';
import 'widget/home_widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The preference file is read before the first frame rather than asynchronously
  // afterwards: the light/dark choice and the language all decide
  // what that first frame looks like, and starting on the defaults and swapping
  // them out afterwards would be a visible flash on every launch.
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  // Read here rather than where it is shown, so the settings screen can paint
  // the version on its first frame instead of swapping it in a moment later.
  final AppVersion appVersion = await AppVersion.load();

  // Opened eagerly so the Room→drift import can finish before anything tries to
  // read a restaurant — including the home-screen widget, which runs in its own
  // isolate and would otherwise race this.
  final AppDatabase database = AppDatabase(openAppDatabase());
  await RoomToDriftImporter(
    database: database,
    locator: const RoomDatabaseFileLocator(),
    preferences: preferences,
  ).run();

  // The home-screen widget's two tails: the App Group it shares with the iOS
  // extension, and the callback its shuffle button runs in the background. The
  // callback is a top-level function because the plugin launches a second
  // engine for it, in its own isolate, and finds it by name.
  await HomeWidget.setAppGroupId(homeWidgetAppGroupId);
  await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);

  // A cold start that came from tapping the widget arrives as one URI, and a
  // tap while the app is already running arrives on the stream; the shell
  // resolves both to the same detail screen.
  final Uri? initialWidgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  final Stream<Uri?> widgetClickStream = HomeWidget.widgetClicked;

  final UserPreferencesRepository userPreferences =
      UserPreferencesRepository(store: preferences);

  // `late` breaks the one cycle there is: the repository has to exist before
  // the widget service (which holds it) and the service has to exist before the
  // repository's callback, which is written as a closure so it is only read —
  // and the still-unassigned `homeWidget` only touched — the first time a write
  // lands, long after both were built.
  late final HomeWidgetService homeWidget;
  final RestaurantRepository restaurantRepository = RestaurantRepository(
    database,
    // The on-device snapshot is written after every change, so a device restore
    // brings the data along without the user ever pressing export.
    backupWriter: const FileBackupWriter(),
    // The photo storage lives on the repository: it is the only place that
    // writes or removes a stored photo, so a delete can take the file with it.
    photoStorage: const FilePhotoStorage(),
    onChanged: () => homeWidget.refresh(),
  );
  homeWidget = HomeWidgetService(
    repository: restaurantRepository,
    preferences: userPreferences,
  );
  // Published once on every launch, so a widget already sitting on the home
  // screen picks up whatever the Room→drift import just brought over — the
  // writes it makes go straight to the database, not through the repository.
  await homeWidget.refresh();

  // "Open with EatApp" hands the file over as an intent, and the plugin
  // resolves a content:// Uri to a real path copied into the cache. The
  // cold-start file arrives once through getInitialMedia, every later one on
  // the stream; both land at the same review screen.
  final ReceiveSharingIntent sharingIntent = ReceiveSharingIntent.instance;
  final String? initialSharedFilePath = _sharedFilePath(
    await sharingIntent.getInitialMedia(),
  );
  // Consume the cold-start file so a later rebuild of the root does not prompt
  // for the same one twice.
  if (initialSharedFilePath != null) {
    await sharingIntent.reset();
  }
  final Stream<String> sharedFileStream = sharingIntent
      .getMediaStream()
      .map(_sharedFilePath)
      .where((String? path) => path != null)
      .cast<String>();

  runApp(
    EatApp(
      preferences: userPreferences,
      repository: restaurantRepository,
      photoPicker: ImagePickerPhotoPicker(),
      appVersion: appVersion,
      initialSharedFilePath: initialSharedFilePath,
      sharedFileStream: sharedFileStream,
      initialWidgetUri: initialWidgetUri,
      widgetClickStream: widgetClickStream,
    ),
  );
}

/// The first readable path among [files], or null when the share carried none.
///
/// The plugin reports each shared item with a `path` (a file path, a URL, or
/// plain text); the import flow only ever wants one that names a file.
String? _sharedFilePath(List<SharedMediaFile> files) {
  for (final SharedMediaFile file in files) {
    if (file.path.isNotEmpty) {
      return file.path;
    }
  }
  return null;
}

/// The application root.
///
/// It publishes the repositories and the photo picker through an [AppScope],
/// selects between the light and dark `ThemeData` the token layer builds, wires
/// up localization and hands the tree its [HomeShell]. Routing itself lives in
/// the shell.
class EatApp extends StatefulWidget {
  const EatApp({
    super.key,
    this.preferences,
    this.repository,
    this.photoPicker,
    this.appVersion,
    this.initialSharedFilePath,
    this.sharedFileStream,
    this.initialWidgetUri,
    this.widgetClickStream,
  });

  /// Null in tests and previews, where an in-memory repository keeps the widget
  /// free of any plugin dependency.
  final UserPreferencesRepository? preferences;

  /// Likewise null in tests and previews, where an in-memory database stands in
  /// for the file-backed one.
  final RestaurantRepository? repository;

  /// Null in tests, where the screens that add a photo are never driven; a fake
  /// stands in for the system picker there.
  final PhotoPicker? photoPicker;

  /// Null in tests, which have no platform to ask. Settings hides its About
  /// section when it is.
  final AppVersion? appVersion;

  /// Null except on the cold start that opened the app via "Open with EatApp"
  /// on a shared restaurant file.
  final String? initialSharedFilePath;

  /// The warm-start counterpart of [initialSharedFilePath] — a new shared file
  /// arriving while the app is already running. Null in tests.
  final Stream<String>? sharedFileStream;

  /// The cold-start deep link from a tap on the home-screen widget, resolved
  /// through `homeWidgetRestaurantId`. Null unless the app was launched that
  /// way.
  final Uri? initialWidgetUri;

  /// The warm-start counterpart of [initialWidgetUri] — a tap on the widget
  /// while the app is already running. Null in tests.
  final Stream<Uri?>? widgetClickStream;

  @override
  State<EatApp> createState() => _EatAppState();
}

class _EatAppState extends State<EatApp> {
  late final UserPreferencesRepository _preferences =
      widget.preferences ?? UserPreferencesRepository();

  late final RestaurantRepository _repository =
      widget.repository ?? RestaurantRepository(AppDatabase.memory());

  late final PhotoPicker _photoPicker =
      widget.photoPicker ?? ImagePickerPhotoPicker();

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
      photoPicker: _photoPicker,
      appVersion: widget.appVersion,
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
            theme: AppTheme.of(mode: AppThemeMode.light),
            darkTheme: AppTheme.of(mode: AppThemeMode.dark),
            themeMode: preferences.themeMode.brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: HomeShell(
              initialSharedFilePath: widget.initialSharedFilePath,
              sharedFileStream: widget.sharedFileStream,
              initialWidgetUri: widget.initialWidgetUri,
              widgetClickStream: widget.widgetClickStream,
            ),
          );
        },
      ),
    );
  }
}
