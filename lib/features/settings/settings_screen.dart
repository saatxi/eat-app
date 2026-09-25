import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme_mode.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/repositories/user_preferences_repository.dart';

/// Settings: the appearance choices, and the data actions.
///
/// Ported from `ui/settings/SettingsScreen.kt`. Exporting and the help guide
/// arrive with the import/export block; the version line with the release
/// polish block.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.onViewStatistics});

  /// Null hides the row — the case in a bare widget test.
  final VoidCallback? onViewStatistics;

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppScope scope = AppScope.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.settingsDeleteAllConfirmTitle),
        content: Text(l10n.settingsDeleteAllConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await scope.restaurants.deleteAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final UserPreferencesRepository preferences =
        AppScope.of(context).preferences;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ValueListenableBuilder<UserPreferences>(
        valueListenable: preferences.listenable,
        builder: (BuildContext context, UserPreferences value, Widget? child) {
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: <Widget>[
              _SectionHeader(l10n.settingsSectionAppearance),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  l10n.settingsPalette,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              for (final AppPalette palette in AppPalette.values)
                ListTile(
                  dense: true,
                  title: Text(_paletteLabel(l10n, palette)),
                  trailing: palette == value.palette
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => preferences.setPalette(palette),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  l10n.settingsThemeMode,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SegmentedButton<AppThemeMode>(
                  segments: <ButtonSegment<AppThemeMode>>[
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.light,
                      label: Text(l10n.themeModeLight),
                      icon: const Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.dark,
                      label: Text(l10n.themeModeDark),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: <AppThemeMode>{value.themeMode},
                  onSelectionChanged: (Set<AppThemeMode> selection) =>
                      preferences.setThemeMode(selection.first),
                ),
              ),
              _SectionHeader(l10n.settingsSectionLanguage),
              // The first entry is "follow the device", which is the stored
              // null — a real choice rather than a missing one, so it gets its
              // own row like the three languages do.
              for (final AppLanguage? language in <AppLanguage?>[
                null,
                ...AppLanguage.selectable,
              ])
                ListTile(
                  dense: true,
                  title: Text(_languageLabel(l10n, language)),
                  trailing: language == value.language
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => preferences.setLanguage(language),
                ),
              _SectionHeader(l10n.settingsSectionData),
              if (onViewStatistics != null)
                ListTile(
                  leading: const Icon(Icons.bar_chart_outlined),
                  title: Text(l10n.settingsActionViewStatistics),
                  onTap: onViewStatistics,
                ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.settingsActionDeleteAllData,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _confirmDeleteAll(context),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _paletteLabel(AppLocalizations l10n, AppPalette palette) =>
      switch (palette) {
        AppPalette.mercadoFresco => l10n.paletteMercadoFresco,
        AppPalette.garden => l10n.paletteGarden,
        AppPalette.indigo => l10n.paletteIndigo,
      };

  static String _languageLabel(AppLocalizations l10n, AppLanguage? language) =>
      language == null
      ? l10n.languageSystem
      : switch (language) {
          AppLanguage.english => l10n.languageEnglish,
          AppLanguage.spanish => l10n.languageSpanish,
          AppLanguage.catalan => l10n.languageCatalan,
        };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
