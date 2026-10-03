import 'dart:convert';

import '../../core/utils/link_validation.dart';
import '../../core/utils/search_normalizer.dart';
import '../db/app_database.dart';

/// The marker every share file carries.
///
/// It is a cheap gate against a file that happens to be valid JSON but isn't
/// ours — the app registers to open plain `.eatapp`/`.json` files, so a
/// stranger's JSON can reach the import path.
///
/// [restaurantShareFormat] is the older v2 tag, still accepted on read;
/// [restaurantShareFormatV3] is what the app writes now, adding the optional
/// group-metadata field. [groupShareFormat] is a whole-group export, whose
/// restaur[ant] list is the same shape, so the reader treats all three alike.
const String restaurantShareFormat = 'eatapp.restaurants.v2';
const String restaurantShareFormatV3 = 'eatapp.restaurants.v3';
const String groupShareFormat = 'eatapp.group.v1';

/// A whole-account backup: the restaurants plus the account code, so restoring
/// the file also restores the identity behind the groups. Unlike the other
/// formats this one carries a bearer secret — the code — and must never be
/// shared casually.
const String accountBackupFormat = 'eatapp.account.v1';

/// Every format tag the importer accepts.
const Set<String> acceptedShareFormats = <String>{
  restaurantShareFormat,
  restaurantShareFormatV3,
  groupShareFormat,
  accountBackupFormat,
};

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
///
/// The favourite flag rides along as [isFavorite] even though it does not live
/// on the [Restaurant] entity at all — it is kept in the user's preferences,
/// keyed by id — so a share/import round-trip carries it the way it carries a
/// visit. Like every other field it is always written, false included, so a
/// reader never has to guess whether its absence means anything.
class RestaurantExport {
  const RestaurantExport({
    required this.name,
    required this.cuisineType,
    required this.priceRange,
    this.streetAddress,
    this.website,
    this.instagram,
    this.city,
    this.region,
    this.country,
    this.isFavorite = false,
    this.visits = const <VisitExport>[],
    this.groupNames = const <String>[],
  });

  final String name;
  final String cuisineType;
  final String? streetAddress;

  /// 0-6, euro price tiers.
  final int priceRange;

  final String? website;
  final String? instagram;
  final String? city;
  final String? region;
  final String? country;

  /// Whether the owner had it in their favourites when it was exported. Not a
  /// column on the restaurant; see the class comment.
  final bool isFavorite;

  final List<VisitExport> visits;

  /// The names of the groups this restaurant was shared into when it was
  /// exported. Informational only: a file cannot grant membership, so the
  /// importer ignores it — it is there so a human can see where a row came from.
  final List<String> groupNames;

  /// The same export, tagged with [groups] — used to fold a group's name into a
  /// whole-group export without mutating the row itself.
  RestaurantExport withGroupNames(List<String> groups) => RestaurantExport(
    name: name,
    cuisineType: cuisineType,
    priceRange: priceRange,
    streetAddress: streetAddress,
    website: website,
    instagram: instagram,
    city: city,
    region: region,
    country: country,
    isFavorite: isFavorite,
    visits: visits,
    groupNames: groups,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'cuisineType': cuisineType,
    'streetAddress': streetAddress,
    'priceRange': priceRange,
    'website': website,
    'instagram': instagram,
    'city': city,
    'region': region,
    'country': country,
    'isFavorite': isFavorite,
    'groups': groupNames,
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
    city: json['city'] as String?,
    region: json['region'] as String?,
    country: json['country'] as String?,
    // Absent on a file the older app wrote, and "not a favourite" is the safe
    // reading of a missing flag.
    isFavorite: json['isFavorite'] as bool? ?? false,
    visits: <VisitExport>[
      for (final Object? visit in json['visits'] as List<Object?>? ?? const <Object?>[])
        if (visit is Map<String, Object?>) VisitExport.fromJson(visit),
    ],
    groupNames: <String>[
      for (final Object? group in json['groups'] as List<Object?>? ?? const <Object?>[])
        if (group is String) group,
    ],
  );
}

/// The top-level shape of a shared/exported file.
class RestaurantShareFile {
  const RestaurantShareFile({
    required this.restaurants,
    this.format = restaurantShareFormatV3,
  });

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

/// The top-level shape of a whole-group export: the group's name plus every
/// restaurant it contained, each carrying the group name so the file is
/// self-describing. Ownership and roles do not travel — a file transfers
/// content, never membership.
class GroupShareFile {
  const GroupShareFile({
    required this.groupName,
    required this.restaurants,
    this.format = groupShareFormat,
  });

  final String groupName;
  final List<RestaurantExport> restaurants;
  final String format;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'groupName': groupName,
    'restaurants': <Map<String, Object?>>[
      for (final RestaurantExport restaurant in restaurants) restaurant.toJson(),
    ],
  };
}

/// Encodes a whole-group export as JSON text.
String encodeGroupShareFile({
  required String groupName,
  required List<RestaurantExport> restaurants,
}) => jsonEncode(
  GroupShareFile(groupName: groupName, restaurants: restaurants).toJson(),
);

/// The top-level shape of an account backup: the account code plus every
/// restaurant, so a restore on a new device brings both the data and the
/// identity.
///
/// The code is a bearer secret — whoever holds the file can adopt the account —
/// so this format is written only by the explicit "back up my data and account"
/// action and never mixed into the shareable restaurant export.
class AccountBackupFile {
  const AccountBackupFile({
    required this.accountCode,
    required this.restaurants,
    this.format = accountBackupFormat,
  });

  final String accountCode;
  final List<RestaurantExport> restaurants;
  final String format;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'account': <String, Object?>{'code': accountCode},
    'restaurants': <Map<String, Object?>>[
      for (final RestaurantExport restaurant in restaurants) restaurant.toJson(),
    ],
  };
}

/// Encodes an account backup — its [accountCode] and [restaurants] — as JSON
/// text.
String encodeAccountBackupFile({
  required String accountCode,
  required List<RestaurantExport> restaurants,
}) => jsonEncode(
  AccountBackupFile(accountCode: accountCode, restaurants: restaurants).toJson(),
);

/// The exportable shape of one [Restaurant], with the visits that live in their
/// own table passed in — they are not derivable from the entity alone.
///
/// [isFavorite] is likewise passed in: the flag lives in the user's preferences
/// rather than the entity, so the caller has to tell this method about it.
RestaurantExport exportRestaurant(
  Restaurant restaurant, {
  List<Visit> visits = const <Visit>[],
  bool isFavorite = false,
}) => RestaurantExport(
  name: restaurant.name,
  cuisineType: restaurant.cuisineType,
  streetAddress: restaurant.streetAddress,
  priceRange: restaurant.priceRange,
  website: restaurant.website,
  instagram: restaurant.instagram,
  city: restaurant.city,
  region: restaurant.region,
  country: restaurant.country,
  isFavorite: isFavorite,
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
    // 0 = "not stamped yet": an import lands as a private local row and the
    // repository stamps updatedAt on its next real write.
    updatedAt: 0,
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
