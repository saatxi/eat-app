import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/app_version.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme_mode.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../data/supabase/identity.dart';
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

/// The account section: sign in with an emailed one-time code, or, once signed
/// in, show the session and offer to sign out. Only ever built when the build
/// carries an identity gateway.
class _AccountSection extends StatefulWidget {
  const _AccountSection({required this.identity});

  final IdentityGateway identity;

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  bool _signedIn = false;
  bool _codeSent = false;
  bool _emailError = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final Identity? me = await widget.identity.current();
    if (!mounted) {
      return;
    }
    setState(() => _signedIn = me != null);
  }

  /// Mails a one-time code to the typed address. Everything else happens inside
  /// the app, so no browser and no redirect are involved.
  Future<void> _sendCode() async {
    final String email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _emailError = true);
      return;
    }
    setState(() {
      _busy = true;
      _emailError = false;
    });
    try {
      await widget.identity.sendEmailCode(email);
      if (mounted) {
        setState(() => _codeSent = true);
      }
    } on Object {
      // The row stays put; the user can ask for another code.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final String email = _email.text.trim();
    final String code = _code.text.trim();
    if (email.isEmpty || code.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.identity.verifyEmailCode(email: email, code: code);
    } on Object {
      // A wrong or expired code leaves the fields as they are, to retype.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      await _refresh();
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await widget.identity.signOut();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_signedIn) {
      return ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: Text(l10n.accountSignedIn),
        trailing: TextButton(
          onPressed: _busy ? null : _signOut,
          child: Text(l10n.accountSignOut),
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
          child: TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.accountEmailLabel,
              errorText: _emailError ? l10n.accountEmailInvalid : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: FilledButton.icon(
            onPressed: _busy ? null : _sendCode,
            icon: const Icon(Icons.mail_outline),
            label: Text(l10n.accountSendCode),
          ),
        ),
        if (_codeSent) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(l10n.accountCodeSent),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _code,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.accountCodeLabel),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: FilledButton(
              onPressed: _busy ? null : _verifyCode,
              child: Text(l10n.accountVerify),
            ),
          ),
        ],
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
