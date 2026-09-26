import 'dart:convert';

import '../../core/utils/link_validation.dart';
import '../../core/utils/search_normalizer.dart';
import '../../core/utils/tag_validation.dart';
import '../db/app_database.dart';

/// The marker every share file carries.
///
/// It is a cheap gate against a file that happens to be valid JSON but isn't
/// ours — the app registers to open plain `.eatapp`/`.json` files, so a
/// stranger's JSON can reach the import path.
const String restaurantShareFormat = 'eatapp.restaurants.v2';

/// On-the-wire shape of one visit.
///
/// No id: it is meaningless (or worse, colliding) once the visit lands in
/// someone else's database, so the receiving side assigns a fresh one. The
/// Android app encoded every field explicitly (`encodeDefaults = true`), and
/// [toJson] mirrors that so the two apps' files stay byte-comparable.
class VisitExport {
  const VisitExport({
    required this.visitDate,
    required this.rating,
    this.notes,
    this.priceRange = 0,
  });

  /// Epoch millis.
  final int visitDate;

  /// 0-5.
  final int rating;

  final String? notes;

  /// 0-6, the same scale as [RestaurantExport.priceRange]; 0 means "not set".
  final int priceRange;

  Map<String, Object?> toJson() => <String, Object?>{
    'visitDate': visitDate,
    'rating': rating,
    'notes': notes,
    'priceRange': priceRange,
  };

  /// Throws when a required field is missing or the wrong type — the reader
  /// treats that as a row to skip, not a file to reject.
  static VisitExport fromJson(Map<String, Object?> json) => VisitExport(
    visitDate: (json['visitDate'] as num).toInt(),
    rating: (json['rating'] as num).toInt(),
    notes: json['notes'] as String?,
    priceRange: (json['priceRange'] as num?)?.toInt() ?? 0,
  );

  /// Whether this visit is inside the ranges the app stores: a rating of 0-5
  /// and a price band of 0-6.
  bool get isValid => rating >= 0 && rating <= 5 && priceRange >= 0 && priceRange <= 6;
}

/// On-the-wire shape of one restaurant in a share/export file.
///
/// Never carries [Restaurant.id] (meaningless in someone else's database) or
/// [Restaurant.searchText] (derived, not data). Photos are deliberately
/// excluded, the same way the Android app's export left them out.
class RestaurantExport {
  const RestaurantExport({
    required this.name,
    required this.cuisineType,
    required this.priceRange,
    this.streetAddress,
    this.website,
    this.instagram,
    this.tags = const <String>[],
    this.city,
    this.region,
    this.country,
    this.visits = const <VisitExport>[],
  });

  final String name;
  final String cuisineType;
  final String? streetAddress;

  /// 0-6, euro price tiers.
  final int priceRange;

  final String? website;
  final String? instagram;
  final List<String> tags;
  final String? city;
  final String? region;
  final String? country;
  final List<VisitExport> visits;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'cuisineType': cuisineType,
    'streetAddress': streetAddress,
    'priceRange': priceRange,
    'website': website,
    'instagram': instagram,
    'tags': tags,
    'city': city,
    'region': region,
    'country': country,
    'visits': <Map<String, Object?>>[for (final VisitExport visit in visits) visit.toJson()],
  };

  /// Tolerant of anything the writer left out — every collection defaults to
  /// empty and every optional string to null — but throws on a missing or
  /// mistyped required field, which the reader turns into a skipped row.
  static RestaurantExport fromJson(Map<String, Object?> json) => RestaurantExport(
    name: json['name'] as String,
    cuisineType: json['cuisineType'] as String,
    streetAddress: json['streetAddress'] as String?,
    priceRange: (json['priceRange'] as num).toInt(),
    website: json['website'] as String?,
    instagram: json['instagram'] as String?,
    tags: <String>[
      for (final Object? tag in json['tags'] as List<Object?>? ?? const <Object?>[])
        if (tag is String) tag,
    ],
    city: json['city'] as String?,
    region: json['region'] as String?,
    country: json['country'] as String?,
    visits: <VisitExport>[
      for (final Object? visit in json['visits'] as List<Object?>? ?? const <Object?>[])
        if (visit is Map<String, Object?>) VisitExport.fromJson(visit),
    ],
  );
}

/// The top-level shape of a shared/exported file.
class RestaurantShareFile {
  const RestaurantShareFile({required this.restaurants, this.format = restaurantShareFormat});

  final String format;
  final List<RestaurantExport> restaurants;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'restaurants': <Map<String, Object?>>[
      for (final RestaurantExport restaurant in restaurants) restaurant.toJson(),
    ],
  };
}

/// Encodes [restaurants] as the JSON text of a share file.
String encodeRestaurantShareFile(List<RestaurantExport> restaurants) =>
    jsonEncode(RestaurantShareFile(restaurants: restaurants).toJson());

/// The exportable shape of one [Restaurant], with the tags and visits that
/// live in their own tables passed in — neither is derivable from the entity
/// alone.
RestaurantExport exportRestaurant(
  Restaurant restaurant, {
  List<String> tags = const <String>[],
  List<Visit> visits = const <Visit>[],
}) => RestaurantExport(
  name: restaurant.name,
  cuisineType: restaurant.cuisineType,
  streetAddress: restaurant.streetAddress,
  priceRange: restaurant.priceRange,
  website: restaurant.website,
  instagram: restaurant.instagram,
  tags: tags,
  city: restaurant.city,
  region: restaurant.region,
  country: restaurant.country,
  visits: <VisitExport>[
    for (final Visit visit in visits)
      VisitExport(
        visitDate: visit.visitDate,
        rating: visit.rating,
        notes: visit.notes,
        priceRange: visit.priceRange,
      ),
  ],
);

/// Validates one exported restaurant exactly like the add/edit form would —
/// this is untrusted input arriving from outside the app. Returns null —
/// dropping just this row — rather than failing the whole file.
///
/// [id] is the fresh UUID the caller assigned. Like the Android reader, a row
/// carrying even one out-of-range visit is dropped whole rather than importing
/// the restaurant with a partial history.
Restaurant? restaurantFromExport(RestaurantExport export, String id) {
  final String name = export.name.trim();
  final String cuisineType = export.cuisineType.trim();
  if (name.isEmpty || cuisineType.isEmpty) {
    return null;
  }
  if (export.priceRange < 0 || export.priceRange > 6) {
    return null;
  }
  if (export.visits.any((VisitExport visit) => !visit.isValid)) {
    return null;
  }

  final String? streetAddress = _blankToNull(export.streetAddress);
  final String? city = _blankToNull(export.city);
  final String? region = _blankToNull(export.region);
  final String? country = _blankToNull(export.country);

  return Restaurant(
    id: id,
    name: name,
    cuisineType: cuisineType,
    streetAddress: streetAddress,
    priceRange: export.priceRange,
    website: normalizeWebsite(export.website),
    instagram: normalizeInstagramHandle(export.instagram),
    city: city,
    region: region,
    country: country,
    searchText: buildSearchText(
      name: name,
      cuisineType: cuisineType,
      streetAddress: streetAddress,
      city: city,
      region: region,
      country: country,
    ),
  );
}

/// The row's visits, already validated as a set by [restaurantFromExport].
List<VisitExport> validatedVisits(RestaurantExport export) =>
    List<VisitExport>.unmodifiable(export.visits);

/// The row's tags, validated the same per-item-lenient way: a blank, over-long
/// or comma-carrying tag is dropped rather than failing the row, duplicates
/// fold together case-insensitively, and the list is capped.
List<String> validatedTagNames(RestaurantExport export) =>
    normalizeTagNames(export.tags);

/// Whether [candidate] looks like [existing] — the same name, and the same
/// address unless either side has none recorded.
///
/// Ported from the Android import screen's private `isLikelyDuplicateOf`. A
/// missing address on either side must not block a match on name alone, or an
/// imported row that never had one would silently land as a second copy instead
/// of being offered as a Replace.
bool isLikelyDuplicateOf(Restaurant candidate, Restaurant existing) {
  final bool sameName =
      candidate.name.trim().toLowerCase() == existing.name.trim().toLowerCase();
  final String candidateAddress = candidate.streetAddress?.trim() ?? '';
  final String existingAddress = existing.streetAddress?.trim() ?? '';
  final bool sameAddress = candidateAddress.isEmpty ||
      existingAddress.isEmpty ||
      candidateAddress.toLowerCase() == existingAddress.toLowerCase();
  return sameName && sameAddress;
}

String? _blankToNull(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
