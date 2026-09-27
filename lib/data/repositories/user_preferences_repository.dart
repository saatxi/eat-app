import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_language.dart';
import '../../core/theme/app_theme_mode.dart';

/// Everything the user has chosen, as opposed to everything that was synced.
///
/// Kept apart from `RestaurantRepository` on purpose: that one is a cache of a
/// re-downloadable file and is wiped whenever the schema changes, which is the
/// correct policy for a cache and the wrong one for the things here.
@immutable
class UserPreferences {
  const UserPreferences({
    required this.themeMode,
    required this.language,
    required this.favoriteIds,
    required this.selectedGroupId,
  });

  final AppThemeMode themeMode;

  /// Null means "no explicit choice yet", so a fresh install follows the
  /// device's language. Unlike [AppLanguage.fallback] this is a real state, not
  /// a degraded one, which is why the field is nullable rather than defaulting
  /// to English.
  final AppLanguage? language;

  /// Ids of favourited restaurants. These are the ids stored in the local
  /// database, which the Room→drift import preserves verbatim, so a favourite
  /// survives the move.
  final Set<String> favoriteIds;

  /// The group the app is currently scoped to, or null for the personal list.
  /// Only the id is kept here — the group's name and membership live on the
  /// remote — so a relaunch reopens on the same group without a network round
  /// trip.
  final String? selectedGroupId;

  /// What the app shows before the stored values have been read back.
  static const UserPreferences defaults = UserPreferences(
    themeMode: AppThemeMode.fallback,
    language: null,
    favoriteIds: <String>{},
    selectedGroupId: null,
  );

  /// [clearLanguage] exists because `language` itself is nullable: without it
  /// there would be no way to tell "leave the language alone" from "go back to
  /// following the device" — and [clearSelectedGroup] is the same idea for
  /// [selectedGroupId].
  UserPreferences copyWith({
    AppThemeMode? themeMode,
    AppLanguage? language,
    bool clearLanguage = false,
    Set<String>? favoriteIds,
    String? selectedGroupId,
    bool clearSelectedGroup = false,
  }) => UserPreferences(
    themeMode: themeMode ?? this.themeMode,
    language: clearLanguage ? null : (language ?? this.language),
    favoriteIds: favoriteIds ?? this.favoriteIds,
    selectedGroupId: clearSelectedGroup
        ? null
        : (selectedGroupId ?? this.selectedGroupId),
  );
}

/// The user's own choices, persisted between launches.
///
/// Every value read back out of storage is treated as untrusted — an enum id
/// renamed between releases degrades to the default instead of throwing, since
/// the preferences file outlives any single version of the app. This mirrors
/// `DataStoreUserPreferencesRepository` on the Android side, including the
/// decision to store favourites as a set of ids rather than one boolean per
/// restaurant (which would leak deleted restaurants into the file forever).
///
/// Change notification is a [ValueNotifier] rather than a `Stream` so the widget
/// tree can read the current value synchronously while building, and rebuild
/// through `ValueListenableBuilder` when it changes.
class UserPreferencesRepository {
  /// Reads from [store], or keeps everything in memory when it is null — which
  /// is what widget tests and the gallery want, and what lets [defaults] be a
  /// usable starting state rather than a special case.
  UserPreferencesRepository({SharedPreferences? store}) : _store = store {
    if (store != null) {
      _value.value = _read(store);
    }
  }

  /// Opens the platform's preference file and loads what it holds.
  static Future<UserPreferencesRepository> open() async =>
      UserPreferencesRepository(store: await SharedPreferences.getInstance());

  static const String _themeModeKey = 'theme_mode';
  static const String _languageKey = 'language';
  static const String _favoriteIdsKey = 'favorite_ids';
  static const String _selectedGroupIdKey = 'selected_group_id';

  final SharedPreferences? _store;
  final ValueNotifier<UserPreferences> _value = ValueNotifier<UserPreferences>(
    UserPreferences.defaults,
  );

  ValueListenable<UserPreferences> get listenable => _value;

  UserPreferences get current => _value.value;

  bool isFavorite(String restaurantId) =>
      current.favoriteIds.contains(restaurantId);

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    final UserPreferences next = current.copyWith(themeMode: themeMode);
    _value.value = next;
    await _store?.setString(_themeModeKey, themeMode.id);
  }

  /// Passing null goes back to following the device's language.
  Future<void> setLanguage(AppLanguage? language) async {
    final UserPreferences next = language == null
        ? current.copyWith(clearLanguage: true)
        : current.copyWith(language: language);
    _value.value = next;
    if (language == null) {
      await _store?.remove(_languageKey);
    } else {
      await _store?.setString(_languageKey, language.languageCode);
    }
  }

  /// Selects the group the app is scoped to, or null to go back to Personal.
  /// Only the id is stored; the group's name is looked up from the gateway.
  Future<void> setSelectedGroup(String? groupId) async {
    final UserPreferences next = groupId == null
        ? current.copyWith(clearSelectedGroup: true)
        : current.copyWith(selectedGroupId: groupId);
    _value.value = next;
    if (groupId == null) {
      await _store?.remove(_selectedGroupIdKey);
    } else {
      await _store?.setString(_selectedGroupIdKey, groupId);
    }
  }

  /// Adds the id if absent, removes it if present.
  Future<void> toggleFavorite(String restaurantId) async {
    final Set<String> next = <String>{...current.favoriteIds};
    if (!next.remove(restaurantId)) {
      next.add(restaurantId);
    }
    _value.value = current.copyWith(favoriteIds: next);
    await _store?.setStringList(_favoriteIdsKey, next.toList());
  }

  static UserPreferences _read(SharedPreferences store) => UserPreferences(
    themeMode: AppThemeMode.fromId(store.getString(_themeModeKey)),
    language: AppLanguage.tryFromLanguageCode(store.getString(_languageKey)),
    favoriteIds: (store.getStringList(_favoriteIdsKey) ?? const <String>[])
        .toSet(),
    selectedGroupId: store.getString(_selectedGroupIdKey),
  );
}
