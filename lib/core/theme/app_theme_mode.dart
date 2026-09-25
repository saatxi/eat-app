import 'package:flutter/material.dart';

/// Light/dark override.
///
/// There is no "follow the system" entry: the Android app deliberately removed
/// that choice, and nothing here reopens it. [brightness] is derived here
/// rather than at the call site so every consumer resolves a mode the same way.
enum AppThemeMode {
  light('light'),
  dark('dark');

  const AppThemeMode(this.id);

  /// Stable, language-independent key used for persistence.
  final String id;

  static const AppThemeMode fallback = AppThemeMode.light;

  Brightness get brightness =>
      this == AppThemeMode.dark ? Brightness.dark : Brightness.light;

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
