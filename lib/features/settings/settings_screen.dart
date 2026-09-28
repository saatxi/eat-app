import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/app_version.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme_mode.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../import_export/share_service.dart';

/// Settings: the appearance choices, the data actions, and which build this is.
///
/// Ported from `ui/settings/SettingsScreen.kt`. The help row the native app had
/// beside the version line is absent: there is no help screen in this app yet,
/// so `settingsActionHelp` has nothing to open.
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
    final AppScope scope = AppScope.of(context);
    final UserPreferencesRepository preferences = scope.preferences;
    final AppVersion? appVersion = scope.appVersion;

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
              _LanguageSelector(
                // Nothing stored means "follow the device", which is what the
                // app is already showing, so the selector opens on the language
                // that was actually resolved rather than on a fourth,
                // non-language row. The same resolution `theme_gallery.dart`
                // uses to name its own language switch.
                value:
                    value.language ??
                    AppLanguage.resolveDeviceLocale(
                      Localizations.localeOf(context),
                    ) ??
                    AppLanguage.fallback,
                labelFor: (AppLanguage language) =>
                    _languageLabel(l10n, language),
                onChanged: preferences.setLanguage,
              ),
              _SectionHeader(l10n.settingsSectionData),
              if (onViewStatistics != null)
                ListTile(
                  leading: const Icon(Icons.bar_chart_outlined),
                  title: Text(l10n.settingsActionViewStatistics),
                  onTap: onViewStatistics,
                ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(l10n.settingsActionExportData),
                onTap: () => exportAndShareRestaurants(
                  context,
                  repository: AppScope.of(context).restaurants,
                ),
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
              // Hidden when there is no platform to ask — a bare widget test.
              // Then the bare version only: what the describe string adds past
              // the tag is build detail, and a settings screen owes nobody the
              // count of commits it happens to be sitting on.
              if (appVersion != null) ...<Widget>[
                _SectionHeader(l10n.settingsSectionAbout),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(
                    l10n.aboutVersionTemplateClean(appVersion.releaseVersion),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _languageLabel(AppLocalizations l10n, AppLanguage language) =>
      switch (language) {
        AppLanguage.english => l10n.languageEnglish,
        AppLanguage.spanish => l10n.languageSpanish,
        AppLanguage.catalan => l10n.languageCatalan,
      };
}

/// The language selector: one row showing the current choice, with the rest of
/// [AppLanguage.selectable] behind a menu.
///
/// Only the languages this app actually ships translations for are offered — a
/// device in a language we don't translate never widens the menu, it just
/// resolves to [AppLanguage.fallback] as it did before.
///
/// Built on `MenuAnchor` rather than a `DropdownButton`, the same way the list
/// screen's filter chips are: the anchor is an ordinary [ListTile] that keeps
/// its own row styling and tap handling, and the choices are plain
/// [MenuItemButton]s. The tick sits on the trailing side, where it already was
/// in the list this replaced, so no row needs a blank spacer to stay aligned.
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.value,
    required this.labelFor,
    required this.onChanged,
  });

  /// The choice the selector opens on. Never null: an unstored preference means
  /// "follow the device", and the caller resolves that to the language the app
  /// is actually showing.
  final AppLanguage value;

  /// The translated name of a choice.
  final String Function(AppLanguage language) labelFor;

  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return MenuAnchor(
      menuChildren: <Widget>[
        for (final AppLanguage language in AppLanguage.selectable)
          MenuItemButton(
            onPressed: () => onChanged(language),
            trailingIcon: language == value
                ? Icon(Icons.check, color: primary)
                : null,
            child: Text(labelFor(language)),
          ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return ListTile(
              leading: const Icon(Icons.language),
              title: Text(labelFor(value)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            );
          },
    );
  }
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
