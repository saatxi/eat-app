import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/app_version.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme_mode.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../data/supabase/identity.dart';
import '../groups/groups_controller.dart';
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
              // Only offered once there is an account to back up: this is the
              // one export whose file carries the account code.
              if (scope.identity != null)
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(l10n.settingsActionBackupAccount),
                  onTap: () => exportAndShareAccountBackup(
                    context,
                    repository: AppScope.of(context).restaurants,
                    identity: scope.identity!,
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
              if (scope.identity != null) ...<Widget>[
                _SectionHeader(l10n.settingsSectionAccount),
                _AccountSection(identity: scope.identity!),
              ],
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

/// The account section: create an account, or, once signed in, the signed-in
/// line with the Delete profile action. Only ever built when the build carries
/// an identity gateway.
///
/// There is no email and nothing to type or copy: the account is made with one
/// tap and its code is kept on the device, never shown. Recovering it on another
/// phone goes through an account backup, not a typed code.
class _AccountSection extends StatefulWidget {
  const _AccountSection({required this.identity});

  final IdentityGateway identity;

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  bool _busy = false;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final Identity? me = await widget.identity.current();
    if (!mounted) {
      return;
    }
    setState(() => _signedIn = me != null);
  }

  /// Mints a brand-new account, adopting it and signing in.
  Future<void> _createAccount() => _run(
    () => widget.identity.createAccount(),
    AppLocalizations.of(context).accountCreateFailed,
  );

  /// Runs an identity action, reloading the groups on success (a fresh sign-in
  /// must bring the account's groups back) or showing [failureMessage] on
  /// error, then refreshing the section either way.
  Future<void> _run(
    Future<Identity> Function() action,
    String failureMessage,
  ) async {
    final GroupsController? groups = AppScope.of(context).groupsController;
    setState(() => _busy = true);
    try {
      await action();
      await groups?.load();
    } on Object {
      _showMessage(failureMessage);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      await _refresh();
    }
  }

  /// Confirms, then erases the account. Nothing happens unless the user
  /// confirms: the dialog is the only guard on an irreversible action.
  Future<void> _confirmDeleteProfile() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.accountDeleteConfirmTitle),
        content: Text(l10n.accountDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.accountDeleteConfirmAction,
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _deleteProfile();
    }
  }

  /// Erases the account, then drops the groups from the UI and returns the
  /// section to its signed-out state.
  Future<void> _deleteProfile() async {
    final GroupsController? groups = AppScope.of(context).groupsController;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await widget.identity.deleteAccount();
      await groups?.load();
    } on Object {
      // The account is untouched if the erase failed, so stay signed in and
      // let the user try again.
      _showMessage(l10n.accountDeleteFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      await _refresh();
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_signedIn) {
      // The code is deliberately never shown: it stays on the device and is
      // copied to the clipboard only when the user asks. So the card is just the
      // signed-in line and its two actions.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            // One row: the signed-in line, then the two icon actions at its
            // end. The title is Expanded so a long translation or a large text
            // scale wraps rather than pushing the actions off the row.
            child: Row(
              children: <Widget>[
                const Icon(Icons.account_circle_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.accountSignedIn,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _confirmDeleteProfile,
                  tooltip: l10n.accountDeleteProfile,
                  icon: Icon(
                    Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(l10n.accountSignInPrompt),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: FilledButton.icon(
            onPressed: _busy ? null : _createAccount,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.accountCreateAction),
          ),
        ),
      ],
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
