import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/link_validation.dart';
import '../../core/utils/search_normalizer.dart';
import '../../core/widgets/presentation_bounds.dart';
import '../../data/db/app_database.dart';
import '../../data/groups/group_models.dart';
import '../../data/photo/photo_picker.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/sync/shared_write.dart';
import '../../data/sync/shared_writes.dart';
import 'restaurant_edit_state.dart';

/// Backs both "add" ([restaurantId] null) and "edit" ([restaurantId] set) — the
/// two only differ in whether a row is loaded to prefill the form and whether
/// saving inserts or updates.
///
/// The Flutter counterpart of the Android `RestaurantEditViewModel`. It also
/// holds the three "suggestions" streams the form offers while typing (cities,
/// regions and countries), which is why it is a controller rather than a plain
/// form object. A photo is picked through [photoPicker] (optional,
/// so a unit test can build a controller with none) and written through the
/// repository, which owns the storage.
class RestaurantEditController extends ChangeNotifier {
  RestaurantEditController({
    required this.repository,
    this.restaurantId,
    this.photoPicker,
    this.sharedWrites,
    this.groups = const <Group>[],
    this.initialGroupId,
  }) {
    _state = RestaurantEditState(
      isLoading: restaurantId != null,
      selectedGroupIds: <String>{?initialGroupId},
    );
    _subscriptions.addAll(<StreamSubscription<Object>>[
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

  /// Resolves the group a save should carry, or null in Personal mode. Without
  /// it (every unit test, and every personal install) writes stay private.
  final SharedWrites? sharedWrites;

  /// The groups the user may share this restaurant into. Empty whenever groups
  /// are off — the form then shows no selector and the write stays private.
  final List<Group> groups;

  /// The group the list is scoped to, used to pre-select a group for a new
  /// restaurant. Null in Personal mode.
  final String? initialGroupId;

  bool get isEditingExisting => restaurantId != null;

  static const Uuid _uuid = Uuid();

  final List<StreamSubscription<Object>> _subscriptions =
      <StreamSubscription<Object>>[];

  /// Initialised in the constructor body: an edit starts loading the row it is
  /// going to prefill, while an add is ready immediately.
  late RestaurantEditState _state;
  List<String> _citySuggestions = const <String>[];
  List<String> _regionSuggestions = const <String>[];
  List<String> _countrySuggestions = const <String>[];

  /// The sharing of the row being edited, captured when it loads, so an edit
  /// keeps the row's group *and its original author* instead of blanking them.
  SharedWrite? _loadedShared;
  bool _disposed = false;

  RestaurantEditState get state => _state;

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

  /// Adds or removes [groupId] from the restaurant's memberships.
  void onToggleGroup(String groupId) {
    final Set<String> next = <String>{..._state.selectedGroupIds};
    if (!next.add(groupId)) {
      next.remove(groupId);
    }
    _set(_state.copyWith(selectedGroupIds: next));
  }

  /// The group that acts as the restaurant's home — the one whose Storage folder
  /// its children use. Prefers the group it already had, else the first choice.
  String? _homeGroup() {
    final Set<String> selected = _state.selectedGroupIds;
    if (selected.isEmpty) {
      return null;
    }
    final String? existing = _loadedShared?.groupId;
    if (existing != null && selected.contains(existing)) {
      return existing;
    }
    return selected.first;
  }

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

    // With no selector — groups off, or a bare test — the write carries the
    // selected group and the row's own author, exactly as before. With the
    // selector in play the home group and author come from the chosen groups:
    // the row's own creator is kept (an edit never reassigns it) and the home
    // group is the row's previous one when still chosen, else the first.
    final String? author;
    final SharedWrite? shared;
    if (groups.isEmpty) {
      shared = restaurantId == null
          ? await sharedWrites?.forNewRow()
          : _loadedShared;
      author = shared?.createdBy;
    } else {
      author = _loadedShared?.createdBy ?? await sharedWrites?.currentUserId();
      final String? home = _homeGroup();
      shared = (home != null && author != null)
          ? SharedWrite(groupId: home, createdBy: author)
          : null;
    }

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
      groupId: shared?.groupId,
      createdBy: shared?.createdBy,
      // Every save is a write, so it stamps the sync timestamp — the same
      // moment the repository would, but here is where the values are in hand.
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (restaurantId == null) {
      await repository.insert(restaurant);
    } else {
      await repository.update(restaurant);
    }

    // The junction is the authoritative membership set: write the chosen groups
    // (and tombstone any dropped) after the row itself. Only when the selector
    // was in play — otherwise the insert above already recorded the home group.
    if (groups.isNotEmpty && author != null) {
      await repository.setRestaurantGroups(
        restaurantId: id,
        groupIds: _state.selectedGroupIds,
        createdBy: author,
      );
    }

    // The photo is written after the row, so a new restaurant has an id to hang
    // it off, and only when the user actually touched it — an untouched edit
    // must not rewrite (and re-encode) the photo that is already there.
    final String? picked = state.pickedPhotoPath;
    if (picked != null) {
      await repository.setRestaurantPhoto(id, picked, shared: shared);
    } else if (state.photoRemoved && state.existingPhotoPath != null) {
      await repository.setRestaurantPhoto(id, null, shared: shared);
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
    _loadedShared = (restaurant.groupId != null && restaurant.createdBy != null)
        ? SharedWrite(
            groupId: restaurant.groupId!,
            createdBy: restaurant.createdBy!,
          )
        : null;
    final String? photoPath = await repository.getRestaurantPhotoPath(id);
    final List<String> memberships = await repository.groupIdsForRestaurant(id);
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
        existingPhotoPath: photoPath,
        selectedGroupIds: memberships.toSet(),
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
