import 'package:eatapp/core/l10n/app_language.dart';
import 'package:eatapp/core/theme/app_theme_mode.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // `setMockInitialValues` swaps the platform channel out for an in-memory
  // store, which needs a binding to exist first.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('in memory, with no store', () {
    test('starts on the defaults', () {
      final UserPreferencesRepository repository = UserPreferencesRepository();

      expect(repository.current.themeMode, AppThemeMode.fallback);
      expect(repository.current.language, isNull);
      expect(repository.current.favoriteIds, isEmpty);
    });

    test('still changes and notifies, so tests and previews can drive it', () async {
      final UserPreferencesRepository repository = UserPreferencesRepository();
      int notifications = 0;
      repository.listenable.addListener(() => notifications++);

      await repository.setThemeMode(AppThemeMode.dark);
      await repository.setLanguage(AppLanguage.catalan);

      expect(repository.current.themeMode, AppThemeMode.dark);
      expect(repository.current.language, AppLanguage.catalan);
      expect(notifications, 2);
    });

    test('a null language means "follow the device", not "fall back"', () async {
      final UserPreferencesRepository repository = UserPreferencesRepository();

      await repository.setLanguage(AppLanguage.spanish);
      expect(repository.current.language, AppLanguage.spanish);

      await repository.setLanguage(null);
      expect(
        repository.current.language,
        isNull,
        reason: 'clearing is a real state, distinct from the English fallback',
      );
    });

    test('toggling a favourite is its own inverse', () async {
      final UserPreferencesRepository repository = UserPreferencesRepository();

      await repository.toggleFavorite('a');
      expect(repository.isFavorite('a'), isTrue);
      expect(repository.current.favoriteIds, <String>{'a'});

      await repository.toggleFavorite('b');
      expect(repository.current.favoriteIds, <String>{'a', 'b'});

      await repository.toggleFavorite('a');
      expect(repository.isFavorite('a'), isFalse);
      expect(repository.current.favoriteIds, <String>{'b'});
    });

    test('each change leaves the other values alone', () async {
      final UserPreferencesRepository repository = UserPreferencesRepository();
      await repository.setLanguage(AppLanguage.spanish);
      await repository.toggleFavorite('a');

      await repository.setThemeMode(AppThemeMode.dark);

      expect(repository.current.themeMode, AppThemeMode.dark);
      expect(repository.current.language, AppLanguage.spanish);
      expect(repository.current.favoriteIds, <String>{'a'});
    });
  });

  group('with a store', () {
    late SharedPreferences store;

    Future<void> openStore([Map<String, Object> initial = const <String, Object>{}]) async {
      SharedPreferences.setMockInitialValues(initial);
      store = await SharedPreferences.getInstance();
    }

    test('persists theme mode, language and favourites', () async {
      await openStore();
      final UserPreferencesRepository first = UserPreferencesRepository(store: store);

      await first.setThemeMode(AppThemeMode.dark);
      await first.setLanguage(AppLanguage.spanish);
      await first.toggleFavorite('r1');
      await first.toggleFavorite('r2');

      // A second repository over the same file is what the next launch sees.
      final UserPreferencesRepository reopened = UserPreferencesRepository(
        store: await SharedPreferences.getInstance(),
      );

      expect(reopened.current.themeMode, AppThemeMode.dark);
      expect(reopened.current.language, AppLanguage.spanish);
      expect(reopened.current.favoriteIds, <String>{'r1', 'r2'});
    });

    test('a stored file with no language key keeps following the device', () async {
      await openStore(<String, Object>{'theme_mode': 'dark'});

      final UserPreferencesRepository repository = UserPreferencesRepository(
        store: store,
      );

      expect(repository.current.themeMode, AppThemeMode.dark);
      expect(
        repository.current.language,
        isNull,
        reason: 'an absent key is not the same as a stored "en"',
      );
    });

    test('an unknown stored value degrades to the default instead of throwing', () async {
      await openStore(<String, Object>{
        'theme_mode': 'sepia',
        'language': 'de',
      });

      final UserPreferencesRepository repository = UserPreferencesRepository(
        store: store,
      );

      expect(repository.current.themeMode, AppThemeMode.fallback);
      expect(repository.current.language, isNull);
    });

    test('clearing the language removes the key rather than storing a fallback', () async {
      await openStore();
      final UserPreferencesRepository repository = UserPreferencesRepository(store: store);
      await repository.setLanguage(AppLanguage.catalan);

      await repository.setLanguage(null);

      expect(store.containsKey('language'), isFalse);
      expect(
        UserPreferencesRepository(store: store).current.language,
        isNull,
      );
    });

    test('every value is written under its stable id, not its enum name', () async {
      await openStore();
      final UserPreferencesRepository repository = UserPreferencesRepository(store: store);

      await repository.setThemeMode(AppThemeMode.light);
      await repository.setLanguage(AppLanguage.catalan);

      expect(store.getString('theme_mode'), 'light');
      expect(store.getString('language'), 'ca');
    });
  });
}
