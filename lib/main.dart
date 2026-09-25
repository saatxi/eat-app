import 'package:flutter/material.dart';

import 'core/l10n/app_language.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'core/theme/theme_gallery.dart';

void main() {
  runApp(const EatApp());
}

/// The application root.
///
/// At this stage it selects between the light and dark `ThemeData` the token
/// layer builds, wires up localization, and shows the token gallery so the
/// design system is visible before any real screen exists. Routing and
/// palette/theme/language persistence arrive in later blocks; everything held
/// here is in-memory only.
class EatApp extends StatefulWidget {
  const EatApp({super.key});

  @override
  State<EatApp> createState() => _EatAppState();
}

class _EatAppState extends State<EatApp> {
  AppPalette _palette = AppPalette.fallback;
  AppThemeMode _mode = AppThemeMode.fallback;

  /// Null until the user picks one explicitly, so a fresh install follows the
  /// device's language (the gallery's picker sets this). Persisting the choice
  /// is a later block.
  AppLanguage? _language;

  void _setPalette(AppPalette palette) {
    setState(() => _palette = palette);
  }

  void _setMode(AppThemeMode mode) {
    setState(() => _mode = mode);
  }

  void _setLanguage(AppLanguage? language) {
    setState(() => _language = language);
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
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _language?.locale,
      localeListResolutionCallback: _resolveLocale,
      // Both brightnesses are provided so Flutter can cross-fade between them
      // when the mode changes, instead of swapping the tree's theme outright.
      theme: AppTheme.of(palette: _palette, mode: AppThemeMode.light),
      darkTheme: AppTheme.of(palette: _palette, mode: AppThemeMode.dark),
      themeMode: _mode.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: ThemeGallery(
        palette: _palette,
        mode: _mode,
        language: _language,
        onPaletteChanged: _setPalette,
        onModeChanged: _setMode,
        onLanguageChanged: _setLanguage,
      ),
    );
  }
}
