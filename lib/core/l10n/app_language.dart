import 'dart:ui' show Locale;

/// The languages the app ships translations for.
///
/// [languageCode] is what gets persisted (the same code the Android app's
/// `values-xx` resource folders use), so entries must not be renamed without a
/// migration; [fromLanguageCode] resolves an unrecognised or absent value to
/// [fallback] instead of throwing, the same graceful degradation the preference
/// reader applies to any other stale stored id.
enum AppLanguage {
  english('en'),
  spanish('es'),
  catalan('ca');

  const AppLanguage(this.languageCode);

  /// Stable, language-independent key used for persistence.
  final String languageCode;

  /// The locale handed to `MaterialApp`, so the framework's own widgets
  /// (date pickers, `Semantics` strings, ...) follow the same choice.
  Locale get locale => Locale(languageCode);

  /// The language a fresh install starts on when the device locale isn't one
  /// we translate, and the one an unknown stored value falls back to.
  static const AppLanguage fallback = AppLanguage.english;

  /// The languages in the order they are offered in the picker.
  static const List<AppLanguage> selectable = <AppLanguage>[
    AppLanguage.english,
    AppLanguage.spanish,
    AppLanguage.catalan,
  ];

  /// Resolves a persisted [languageCode], falling back rather than throwing so
  /// stale preference data can never crash startup.
  static AppLanguage fromLanguageCode(String? languageCode) =>
      tryFromLanguageCode(languageCode) ?? fallback;

  /// Like [fromLanguageCode], but null when nothing matches — which the
  /// preferences layer needs, because for it an absent value means "follow the
  /// device" rather than "fall back to English".
  static AppLanguage? tryFromLanguageCode(String? languageCode) {
    for (final AppLanguage language in values) {
      if (language.languageCode == languageCode) {
        return language;
      }
    }
    return null;
  }

  /// Resolves the best shipped language for a device [deviceLocale], matching
  /// on the language subtag only (`es_ES` and `es-419` both map to [spanish]).
  static AppLanguage? resolveDeviceLocale(Locale? deviceLocale) {
    final String? code = deviceLocale?.languageCode;
    for (final AppLanguage language in values) {
      if (language.languageCode == code) {
        return language;
      }
    }
    return null;
  }
}
