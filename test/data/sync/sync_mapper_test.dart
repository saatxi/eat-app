import 'package:drift/drift.dart' hide isNull;
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/sync/remote_models.dart';
import 'package:eatapp/data/sync/sync_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

Restaurant sharedRestaurant() => Restaurant(
  id: 'r1',
  groupId: 'g1',
  name: 'Cal Ferran',
  cuisineType: 'italian',
  streetAddress: 'Carrer Major 1',
  priceRange: 2,
  website: 'https://example.com',
  instagram: 'calferran',
  city: 'Barcelona',
  region: null,
  country: 'Spain',
  searchText: 'cal ferran italian carrer major 1 barcelona spain',
  createdBy: 'u1',
  updatedAt: 1000,
  deletedAt: null,
);

void main() {
  test('toRemoteRestaurant maps every field and its timestamps', () {
    final RemoteRestaurant remote = toRemoteRestaurant(sharedRestaurant());

    expect(remote.id, 'r1');
    expect(remote.groupId, 'g1');
    expect(remote.name, 'Cal Ferran');
    expect(remote.cuisineType, 'italian');
    expect(remote.address, 'Carrer Major 1');
    expect(remote.priceRange, 2);
    expect(remote.website, 'https://example.com');
    expect(remote.instagram, 'calferran');
    expect(remote.city, 'Barcelona');
    expect(remote.country, 'Spain');
    expect(remote.createdBy, 'u1');
    expect(remote.updatedAt, isoFromEpochMillis(1000));
    expect(remote.deletedAt, isNull);
  });

  test('toRemoteRestaurant throws on a private or unattributed row', () {
    final Restaurant private = sharedRestaurant().copyWith(
      groupId: const Value<String?>(null),
    );
    expect(() => toRemoteRestaurant(private), throwsA(isA<SyncException>()));

    final Restaurant unattributed = sharedRestaurant().copyWith(
      createdBy: const Value<String?>(null),
    );
    expect(
      () => toRemoteRestaurant(unattributed),
      throwsA(isA<SyncException>()),
    );
  });

  test('toRestaurant rebuilds searchText and converts timestamps', () {
    final RemoteRestaurant remote = RemoteRestaurant(
      id: 'r9',
      groupId: 'g1',
      name: 'Remote',
      cuisineType: 'japanese',
      address: null,
      priceRange: 1,
      website: null,
      instagram: null,
      city: 'Kyoto',
      region: null,
      country: 'Japan',
      createdBy: 'u2',
      updatedAt: '2026-09-27T10:00:00.000Z',
      deletedAt: '2026-09-27T11:00:00.000Z',
    );

    final Restaurant row = toRestaurant(remote);

    expect(row.id, 'r9');
    expect(row.groupId, 'g1');
    expect(row.searchText, contains('remote'));
    expect(row.searchText, contains('kyoto'));
    expect(row.updatedAt, epochMillisFromIso('2026-09-27T10:00:00.000Z'));
    expect(row.deletedAt, epochMillisFromIso('2026-09-27T11:00:00.000Z'));
  });

  test('toRemoteVisit and toVisit round-trip the sync fields', () {
    final Visit local = Visit(
      id: 'v1',
      groupId: 'g1',
      restaurantId: 'r1',
      visitDate: 1700000000000,
      rating: 4,
      notes: 'nice',
      priceRange: 2,
      createdBy: 'u1',
      updatedAt: 2000,
      deletedAt: 3000,
    );

    final Visit back = toVisit(toRemoteVisit(local));

    expect(back.id, 'v1');
    expect(back.groupId, 'g1');
    expect(back.restaurantId, 'r1');
    expect(back.visitDate, 1700000000000);
    expect(back.rating, 4);
    expect(back.notes, 'nice');
    expect(back.createdBy, 'u1');
    expect(back.updatedAt, 2000);
    expect(back.deletedAt, 3000);
  });

  test('the timestamp helpers are each other\'s inverse', () {
    expect(epochMillisFromIso(isoFromEpochMillis(1234567)), 1234567);
    expect(epochMillisFromIso(null), isNull);
  });
}
