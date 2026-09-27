/// The row shapes the sync layer exchanges with the remote, in the remote's
/// own terms.
///
/// Timestamps are ISO-8601 UTC strings (Supabase `timestamptz`) rather than the
/// drift schema's epoch millis, and columns carry the names the Supabase
/// schema uses — not the drift getters — so the real transport maps rows
/// without a translation table in between. Only [SyncException] and the two
/// timestamp helpers live here besides the models.
library;

/// A restaurant as it travels to and from the remote.
class RemoteRestaurant {
  const RemoteRestaurant({
    required this.id,
    required this.groupId,
    required this.name,
    required this.cuisineType,
    required this.address,
    required this.priceRange,
    required this.website,
    required this.instagram,
    required this.city,
    required this.region,
    required this.country,
    required this.createdBy,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String groupId;
  final String name;
  final String cuisineType;
  final String? address;
  final int priceRange;
  final String? website;
  final String? instagram;
  final String? city;
  final String? region;
  final String? country;
  final String createdBy;

  /// ISO-8601 UTC. On a push this is the local write's timestamp; the remote
  /// replaces it with its own clock, which is what a later pull returns.
  final String updatedAt;

  /// ISO-8601 UTC, or null while the row is alive. A tombstone pulls with this
  /// set, which is how a deletion reaches every member.
  final String? deletedAt;
}

/// A visit as it travels to and from the remote.
class RemoteVisit {
  const RemoteVisit({
    required this.id,
    required this.groupId,
    required this.restaurantId,
    required this.visitDate,
    required this.rating,
    required this.notes,
    required this.priceRange,
    required this.createdBy,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String groupId;
  final String restaurantId;

  /// Epoch millis.
  final int visitDate;
  final int rating;
  final String? notes;
  final int priceRange;
  final String createdBy;
  final String updatedAt;
  final String? deletedAt;
}

/// Something went wrong in the sync layer, in terms the app can log or show.
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => 'SyncException: $message';
}

/// Formats a local epoch-millis instant as the remote's ISO-8601 UTC string.
String isoFromEpochMillis(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toIso8601String();

/// Parses an ISO-8601 timestamp (with optional `Z` and fractional seconds)
/// back to epoch millis, or null for a null timestamp.
int? epochMillisFromIso(String? iso) =>
    iso == null ? null : DateTime.parse(iso).millisecondsSinceEpoch;
