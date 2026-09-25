import 'package:flutter/material.dart';

import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'core/theme/theme_gallery.dart';

void main() {
  runApp(const EatApp());
}

/// The application root.
///
/// At this stage it only selects between the light and dark `ThemeData` the
/// token layer builds, and shows the token gallery so the design system is
/// visible before any real screen exists. Palette/theme persistence, routing
/// and localization arrive in the following blocks; the palette and mode here
/// are in-memory only.
class EatApp extends StatefulWidget {
  const EatApp({super.key});

  @override
  State<EatApp> createState() => _EatAppState();
}

class _EatAppState extends State<EatApp> {
  AppPalette _palette = AppPalette.fallback;
  AppThemeMode _mode = AppThemeMode.fallback;

  void _setPalette(AppPalette palette) {
    setState(() => _palette = palette);
  }

  void _setMode(AppThemeMode mode) {
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EatApp',
      debugShowCheckedModeBanner: false,
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
        onPaletteChanged: _setPalette,
        onModeChanged: _setMode,
      ),
    );
  }
}
