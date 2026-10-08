import 'package:flutter/material.dart';

/// Light/dark/system theme choice.
///
/// [brightness] is derived here for the palette gallery and contrast tests,
/// which need a single brightness value; [system] falls back to light there.
/// [toThemeMode] is what [MaterialApp] consumes at runtime.
enum AppThemeMode {
  light('light'),
  dark('dark'),
  system('system');

  const AppThemeMode(this.id);

  /// Stable, language-independent key used for persistence.
  final String id;

  static const AppThemeMode fallback = AppThemeMode.light;

  /// Resolved brightness for gallery/test consumers that need a concrete value.
  /// [system] falls back to light — only [toThemeMode] triggers the OS query.
  Brightness get brightness =>
      this == AppThemeMode.dark ? Brightness.dark : Brightness.light;

  /// The [ThemeMode] passed to [MaterialApp], so the framework follows the OS
  /// when [system] is selected.
  ThemeMode get toThemeMode => switch (this) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  /// Resolves a persisted [id], falling back rather than throwing.
  static AppThemeMode fromId(String? id) {
    for (final AppThemeMode mode in values) {
      if (mode.id == id) {
        return mode;
      }
    }
    return fallback;
  }
}
