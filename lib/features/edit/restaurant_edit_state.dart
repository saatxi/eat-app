import 'package:flutter/foundation.dart';

/// The restaurant form's fields, plus the validation flags [RestaurantEditState]
/// carries once a save is attempted.
///
/// Place-level data only: rating, "visited" and notes live on a visit, and a new
/// restaurant starts with none — which is exactly what "want to try" means.
@immutable
class RestaurantEditState {
  const RestaurantEditState({
    this.isLoading = false,
    this.name = '',
    this.cuisineType,
    this.streetAddress = '',
    this.city = '',
    this.region = '',
    this.country = '',
    this.priceRange = 0,
    this.website = '',
    this.instagram = '',
    this.tags = const <String>[],
    this.nameError = false,
    this.cuisineError = false,
    this.websiteError = false,
    this.instagramError = false,
  });

  /// True while an existing restaurant is still loading in edit mode.
  final bool isLoading;

  final String name;

  /// The stored cuisine key, or null until one is chosen.
  final String? cuisineType;

  final String streetAddress;
  final String city;
  final String region;
  final String country;

  /// 0-6, 0 meaning "not set".
  final int priceRange;

  final String website;
  final String instagram;
  final List<String> tags;

  final bool nameError;
  final bool cuisineError;
  final bool websiteError;
  final bool instagramError;

  /// [cuisineType] is the only nullable field the form changes, and it is only
  /// ever set (never cleared back to "no cuisine" once chosen), so a plain
  /// named parameter with a null-means-keep default is enough — no sentinel.
  RestaurantEditState copyWith({
    bool? isLoading,
    String? name,
    String? cuisineType,
    String? streetAddress,
    String? city,
    String? region,
    String? country,
    int? priceRange,
    String? website,
    String? instagram,
    List<String>? tags,
    bool? nameError,
    bool? cuisineError,
    bool? websiteError,
    bool? instagramError,
  }) => RestaurantEditState(
    isLoading: isLoading ?? this.isLoading,
    name: name ?? this.name,
    cuisineType: cuisineType ?? this.cuisineType,
    streetAddress: streetAddress ?? this.streetAddress,
    city: city ?? this.city,
    region: region ?? this.region,
    country: country ?? this.country,
    priceRange: priceRange ?? this.priceRange,
    website: website ?? this.website,
    instagram: instagram ?? this.instagram,
    tags: tags ?? this.tags,
    nameError: nameError ?? this.nameError,
    cuisineError: cuisineError ?? this.cuisineError,
    websiteError: websiteError ?? this.websiteError,
    instagramError: instagramError ?? this.instagramError,
  );
}
