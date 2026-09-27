import '../../core/utils/search_normalizer.dart';
import '../db/app_database.dart';
import 'remote_models.dart';

/// Converts drift rows to remote models and back — the only place the two
/// column naming schemes meet.
///
/// Pushing requires the row to be shared: a private row (`groupId` null) or
/// one that was never attributed (`createdBy` null) has no business leaving
/// the device, so mapping it throws rather than silently shipping it. Pulling
/// in the other direction rebuilds `searchText` with [buildSearchText], because
/// that column is deliberately not stored remotely.
RemoteRestaurant toRemoteRestaurant(Restaurant r) {
  final String groupId = _requireShared(r.groupId, 'restaurant', r.id);
  final String createdBy = _requireShared(r.createdBy, 'restaurant', r.id);
  return RemoteRestaurant(
    id: r.id,
    groupId: groupId,
    name: r.name,
    cuisineType: r.cuisineType,
    address: r.streetAddress,
    priceRange: r.priceRange,
    website: r.website,
    instagram: r.instagram,
    city: r.city,
    region: r.region,
    country: r.country,
    createdBy: createdBy,
    updatedAt: isoFromEpochMillis(r.updatedAt),
    deletedAt: r.deletedAt == null ? null : isoFromEpochMillis(r.deletedAt!),
  );
}

/// Rebuilds the drift row from a remote one, deriving `searchText` locally.
Restaurant toRestaurant(RemoteRestaurant r) => Restaurant(
  id: r.id,
  groupId: r.groupId,
  name: r.name,
  cuisineType: r.cuisineType,
  streetAddress: r.address,
  priceRange: r.priceRange,
  website: r.website,
  instagram: r.instagram,
  city: r.city,
  region: r.region,
  country: r.country,
  searchText: buildSearchText(
    name: r.name,
    cuisineType: r.cuisineType,
    streetAddress: r.address,
    city: r.city,
    region: r.region,
    country: r.country,
  ),
  createdBy: r.createdBy,
  updatedAt: epochMillisFromIso(r.updatedAt)!,
  deletedAt: epochMillisFromIso(r.deletedAt),
);

RemoteVisit toRemoteVisit(Visit v) {
  final String groupId = _requireShared(v.groupId, 'visit', v.id);
  final String createdBy = _requireShared(v.createdBy, 'visit', v.id);
  return RemoteVisit(
    id: v.id,
    groupId: groupId,
    restaurantId: v.restaurantId,
    visitDate: v.visitDate,
    rating: v.rating,
    notes: v.notes,
    priceRange: v.priceRange,
    createdBy: createdBy,
    updatedAt: isoFromEpochMillis(v.updatedAt),
    deletedAt: v.deletedAt == null ? null : isoFromEpochMillis(v.deletedAt!),
  );
}

Visit toVisit(RemoteVisit v) => Visit(
  id: v.id,
  groupId: v.groupId,
  restaurantId: v.restaurantId,
  visitDate: v.visitDate,
  rating: v.rating,
  notes: v.notes,
  priceRange: v.priceRange,
  createdBy: v.createdBy,
  updatedAt: epochMillisFromIso(v.updatedAt)!,
  deletedAt: epochMillisFromIso(v.deletedAt),
);

String _requireShared(String? value, String kind, String id) {
  if (value == null) {
    throw SyncException('cannot push a private or unattributed $kind $id');
  }
  return value;
}
