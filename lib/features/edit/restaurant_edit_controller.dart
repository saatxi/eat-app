import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/link_validation.dart';
import '../../core/utils/search_normalizer.dart';
import '../../core/utils/tag_validation.dart';
import '../../core/widgets/presentation_bounds.dart';
import '../../data/db/app_database.dart';
import '../../data/photo/photo_picker.dart';
import '../../data/repositories/restaurant_repository.dart';
import 'restaurant_edit_state.dart';

/// Backs both "add" ([restaurantId] null) and "edit" ([restaurantId] set) — the
/// two only differ in whether a row is loaded to prefill the form and whether
/// saving inserts or updates.
///
/// The Flutter counterpart of the Android `RestaurantEditViewModel`. It also
/// holds the four "suggestions" streams the form offers while typing (existing
/// tags, cities, regions and countries), which is why it is a controller rather
/// than a plain form object. A photo is picked through [photoPicker] (optional,
/// so a unit test can build a controller with none) and written through the
/// repository, which owns the storage.
class RestaurantEditController extends ChangeNotifier {
  RestaurantEditController({
    required this.repository,
    this.restaurantId,
    this.photoPicker,
  }) {
    _state = RestaurantEditState(isLoading: restaurantId != null);
    _subscriptions.addAll(<StreamSubscription<Object>>[
      repository.observeAllTagNames().listen((List<String> value) {
        _tagSuggestions = value;
        _notify();
      }),
      repository.observeCities().listen((List<String> value) {
        _citySuggestions = value;
        _notify();
      }),
      repository.observeRegions().listen((List<String> value) {
        _regionSuggestions = value;
        _notify();
      }),
      repository.observeCountries().listen((List<String> value) {
        _countrySuggestions = value;
        _notify();
      }),
    ]);

    final String? id = restaurantId;
    if (id != null) {
      unawaited(_load(id));
    }
  }

  final RestaurantRepository repository;
  final String? restaurantId;

  /// Opens the system picker for the restaurant's photo. Null in a unit test
  /// that never picks one, in which case [pickPhoto] is a no-op.
  final PhotoPicker? photoPicker;

  bool get isEditingExisting => restaurantId != null;

  static const Uuid _uuid = Uuid();

  final List<StreamSubscription<Object>> _subscriptions =
      <StreamSubscription<Object>>[];

  /// Initialised in the constructor body: an edit starts loading the row it is
  /// going to prefill, while an add is ready immediately.
  late RestaurantEditState _state;
  List<String> _tagSuggestions = const <String>[];
  List<String> _citySuggestions = const <String>[];
  List<String> _regionSuggestions = const <String>[];
  List<String> _countrySuggestions = const <String>[];
  bool _disposed = false;

  RestaurantEditState get state => _state;

  List<String> get tagSuggestions => _tagSuggestions;
  List<String> get citySuggestions => _citySuggestions;
  List<String> get regionSuggestions => _regionSuggestions;
  List<String> get countrySuggestions => _countrySuggestions;

  void onNameChange(String name) =>
      _set(_state.copyWith(name: name, nameError: false));

  void onCuisineChange(String cuisineType) =>
      _set(_state.copyWith(cuisineType: cuisineType, cuisineError: false));

  void onStreetAddressChange(String value) =>
      _set(_state.copyWith(streetAddress: value));

  void onCityChange(String value) => _set(_state.copyWith(city: value));

  void onRegionChange(String value) => _set(_state.copyWith(region: value));

  void onCountryChange(String value) => _set(_state.copyWith(country: value));

  void onPriceRangeChange(int priceRange) => _set(
        _state.copyWith(priceRange: priceRange.clamp(0, maxPriceRange)),
      );

  void onWebsiteChange(String value) =>
      _set(_state.copyWith(website: value, websiteError: false));

  void onInstagramChange(String value) =>
      _set(_state.copyWith(instagram: value, instagramError: false));

  /// Ignored when [raw] fails validation or already matches a tag already
  /// added, case-insensitively.
  void addTag(String raw) {
    final String? normalized = normalizeTagName(raw);
    if (normalized == null) {
      return;
    }
    if (_state.tags.any(
      (String tag) => tag.toLowerCase() == normalized.toLowerCase(),
    )) {
      return;
    }
    _set(_state.copyWith(tags: <String>[..._state.tags, normalized]));
  }

  void removeTag(String name) => _set(
        _state.copyWith(
          tags: <String>[
            for (final String tag in _state.tags)
              if (tag != name) tag,
          ],
        ),
      );

  /// Opens the picker and stages whatever comes back. Nothing is written until
  /// [save]: a back-out leaves the form, and the database, untouched.
  Future<void> pickPhoto() async {
    final String? path = await photoPicker?.pickFromGallery();
    if (path == null || _disposed) {
      return;
    }
    _set(_state.copyWith(pickedPhotoPath: path, photoRemoved: false));
  }

  /// Clears the photo, whether that is a stored one or a just-picked one. A new
  /// pick afterwards simply overrides this.
  void removePhoto() => _set(
        _state.copyWith(
          clearPickedPhoto: true,
          photoRemoved: _state.existingPhotoPath != null,
        ),
      );

  /// Validates the form and, if it passes, inserts or updates the restaurant.
  /// Returns false when something was flagged, leaving the caller on the form.
  Future<bool> save() async {
    final RestaurantEditState state = _state;
    final String name = state.name.trim();
    final String? website = state.website.trim().isEmpty
        ? null
        : normalizeWebsite(state.website);
    final String? instagram = state.instagram.trim().isEmpty
        ? null
        : normalizeInstagramHandle(state.instagram);

    final bool nameError = name.isEmpty;
    final bool cuisineError = state.cuisineType == null;
    final bool websiteError = state.website.trim().isNotEmpty && website == null;
    final bool instagramError =
        state.instagram.trim().isNotEmpty && instagram == null;

    if (nameError || cuisineError || websiteError || instagramError) {
      _set(
        state.copyWith(
          nameError: nameError,
          cuisineError: cuisineError,
          websiteError: websiteError,
          instagramError: instagramError,
        ),
      );
      return false;
    }

    final String cuisineType = state.cuisineType!;
    final String? streetAddress = _nonBlank(state.streetAddress);
    final String? city = _nonBlank(state.city);
    final String? region = _nonBlank(state.region);
    final String? country = _nonBlank(state.country);

    final String id = restaurantId ?? _uuid.v4();
    final Restaurant restaurant = Restaurant(
      id: id,
      name: name,
      cuisineType: cuisineType,
      streetAddress: streetAddress,
      city: city,
      region: region,
      country: country,
      priceRange: state.priceRange,
      website: website,
      instagram: instagram,
      // The search column is derived, not typed, so it is rebuilt here from the
      // same fields the query folds — the DAOs deliberately do not do this.
      searchText: buildSearchText(
        name: name,
        cuisineType: cuisineType,
        streetAddress: streetAddress,
        city: city,
        region: region,
        country: country,
      ),
    );

    if (restaurantId == null) {
      await repository.insert(restaurant, tags: state.tags);
    } else {
      await repository.update(restaurant, state.tags);
    }

    // The photo is written after the row, so a new restaurant has an id to hang
    // it off, and only when the user actually touched it — an untouched edit
    // must not rewrite (and re-encode) the photo that is already there.
    final String? picked = state.pickedPhotoPath;
    if (picked != null) {
      await repository.setRestaurantPhoto(id, picked);
    } else if (state.photoRemoved && state.existingPhotoPath != null) {
      await repository.setRestaurantPhoto(id, null);
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final StreamSubscription<Object> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    super.dispose();
  }

  Future<void> _load(String id) async {
    final Restaurant? restaurant = await repository.observeById(id).first;
    if (_disposed) {
      return;
    }
    if (restaurant == null) {
      _set(_state.copyWith(isLoading: false));
      return;
    }
    final List<String> tags = await repository.observeTagNames(id).first;
    if (_disposed) {
      return;
    }
    final String? photoPath = await repository.getRestaurantPhotoPath(id);
    if (_disposed) {
      return;
    }
    _set(
      RestaurantEditState(
        isLoading: false,
        name: restaurant.name,
        cuisineType: restaurant.cuisineType,
        streetAddress: restaurant.streetAddress ?? '',
        city: restaurant.city ?? '',
        region: restaurant.region ?? '',
        country: restaurant.country ?? '',
        priceRange: restaurant.priceRange,
        website: restaurant.website ?? '',
        instagram: restaurant.instagram ?? '',
        tags: tags,
        existingPhotoPath: photoPath,
      ),
    );
  }

  void _set(RestaurantEditState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  /// [notifyListeners] already no-ops after disposal, but the state write would
  /// not, so guard the whole hand-off.
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  static String? _nonBlank(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
