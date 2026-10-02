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
  final String createdBy = _requireShared(r.createdBy, 'restaurant', r.id);
  return RemoteRestaurant(
    id: r.id,
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
///
/// [homeGroupId] is the group the row is being pulled for: the remote carries
/// no group on a restaurant, so a row new to this device adopts the group it
/// arrived through as its home group. An existing row keeps its own.
Restaurant toRestaurant(RemoteRestaurant r, {String? homeGroupId}) => Restaurant(
  id: r.id,
  groupId: homeGroupId,
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

RemoteRestaurantGroup toRemoteRestaurantGroup(RestaurantGroup rg) {
  final String createdBy = _requireShared(
    rg.createdBy,
    'restaurant group',
    rg.restaurantId,
  );
  return RemoteRestaurantGroup(
    restaurantId: rg.restaurantId,
    groupId: rg.groupId,
    createdBy: createdBy,
    updatedAt: isoFromEpochMillis(rg.updatedAt),
    deletedAt: rg.deletedAt == null ? null : isoFromEpochMillis(rg.deletedAt!),
  );
}

/// Rebuilds a membership row from a remote one.
RestaurantGroup toRestaurantGroup(RemoteRestaurantGroup rg) => RestaurantGroup(
  restaurantId: rg.restaurantId,
  groupId: rg.groupId,
  createdBy: rg.createdBy,
  updatedAt: epochMillisFromIso(rg.updatedAt)!,
  deletedAt: epochMillisFromIso(rg.deletedAt),
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

/// The bucket key a photo's binary lives at: one folder per group, so the
/// Storage rules can scope access the same way the row RLS does.
String photoStoragePath({required String groupId, required String photoId}) =>
    '$groupId/$photoId';

RemotePhoto toRemotePhoto(Photo p) {
  final String groupId = _requireShared(p.groupId, 'photo', p.id);
  final String createdBy = _requireShared(p.createdBy, 'photo', p.id);
  return RemotePhoto(
    id: p.id,
    groupId: groupId,
    restaurantId: p.restaurantId,
    visitId: p.visitId,
    position: p.position,
    storagePath: photoStoragePath(groupId: groupId, photoId: p.id),
    createdBy: createdBy,
    updatedAt: isoFromEpochMillis(p.updatedAt),
    deletedAt: p.deletedAt == null ? null : isoFromEpochMillis(p.deletedAt!),
  );
}

/// Rebuilds the drift row from a remote one. [localPath] is where the pulled
/// binary now sits on this device — the remote row only names the bucket object.
Photo toPhoto(RemotePhoto r, {required String localPath}) => Photo(
  id: r.id,
  groupId: r.groupId,
  restaurantId: r.restaurantId,
  visitId: r.visitId,
  path: localPath,
  position: r.position,
  createdBy: r.createdBy,
  updatedAt: epochMillisFromIso(r.updatedAt)!,
  deletedAt: epochMillisFromIso(r.deletedAt),
);

String _requireShared(String? value, String kind, String id) {
  if (value == null) {
    throw SyncException('cannot push a private or unattributed $kind $id');
  }
  return value;
}
