import 'package:eatapp/core/l10n/app_language.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLanguage', () {
    test('resolves stored codes and falls back safely', () {
      expect(AppLanguage.fromLanguageCode('es'), AppLanguage.spanish);
      expect(AppLanguage.fromLanguageCode('ca'), AppLanguage.catalan);
      expect(AppLanguage.fromLanguageCode('fr'), AppLanguage.fallback);
      expect(AppLanguage.fromLanguageCode(null), AppLanguage.fallback);
      expect(AppLanguage.fallback, AppLanguage.english);
    });

    test('resolves a device locale on its language subtag only', () {
      expect(
        AppLanguage.resolveDeviceLocale(const Locale('ca', 'ES')),
        AppLanguage.catalan,
      );
      expect(
        AppLanguage.resolveDeviceLocale(const Locale('es', 'MX')),
        AppLanguage.spanish,
      );
      expect(AppLanguage.resolveDeviceLocale(const Locale('fr')), isNull);
      expect(AppLanguage.resolveDeviceLocale(null), isNull);
    });

    test('builds a locale from its own code, in the offered order', () {
      for (final AppLanguage language in AppLanguage.selectable) {
        expect(language.locale.languageCode, language.languageCode);
      }
      expect(
        AppLanguage.selectable,
        orderedEquals(<AppLanguage>[
          AppLanguage.english,
          AppLanguage.spanish,
          AppLanguage.catalan,
        ]),
      );
    });
  });

  group('AppLocalizations', () {
    test('ships exactly the languages AppLanguage offers', () {
      expect(
        AppLocalizations.supportedLocales
            .map((Locale locale) => locale.languageCode)
            .toSet(),
        AppLanguage.selectable
            .map((AppLanguage language) => language.languageCode)
            .toSet(),
      );
    });

    test('carries the framework delegates alongside its own', () {
      expect(
        AppLocalizations.localizationsDelegates,
        containsAll(<LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ]),
      );
    });

    test('translates a plain string in every locale', () {
      expect(
        lookupAppLocalizations(const Locale('en')).listTitle,
        'My Restaurants',
      );
      expect(
        lookupAppLocalizations(const Locale('es')).listTitle,
        'Mis restaurantes',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).listTitle,
        'Els meus restaurants',
      );
    });

    test('interpolates placeholders positionally', () {
      expect(
        lookupAppLocalizations(const Locale('en')).listFilterLocationActive(2),
        'Location · 2',
      );
      expect(
        lookupAppLocalizations(
          const Locale('ca'),
        ).aboutVersionTemplate('2.4.1', 139, 'abc123'),
        'Versió 2.4.1 (compilació 139, abc123)',
      );
      expect(
        lookupAppLocalizations(const Locale('es')).detailLinkHandleFormat(
          'eatapp',
        ),
        '@eatapp',
      );
    });

    test('picks the singular and plural forms', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      expect(en.listResultCount(1), '1 restaurant');
      expect(en.listResultCount(4), '4 restaurants');

      final AppLocalizations ca = lookupAppLocalizations(const Locale('ca'));
      expect(ca.listResultCount(1), '1 restaurant');
      expect(ca.listResultCount(4), '4 restaurants');
      expect(ca.importDuplicatesHeader(1), '1 ja hi és a la teva llista');
      expect(ca.importDuplicatesHeader(3), '3 ja hi són a la teva llista');
    });

    test('formats numbers with the locale decimal separator', () {
      expect(
        lookupAppLocalizations(const Locale('en')).statsAverageRatingValue(4.3),
        '4.3',
      );
      expect(
        lookupAppLocalizations(const Locale('es')).statsAverageRatingValue(4.3),
        '4,3',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).statsAverageRatingValue(4.3),
        '4,3',
      );
    });
  });
}
