import 'package:eatapp/data/sync/remote_models.dart';
import 'package:eatapp/data/sync/supabase_transport.dart';
import 'package:flutter_test/flutter_test.dart';

RemoteRestaurant restaurant() => RemoteRestaurant(
  id: 'r1',
  groupId: 'g1',
  name: 'Cal Ferran',
  cuisineType: 'italian',
  address: 'Carrer Major 1',
  priceRange: 2,
  website: 'https://example.com',
  instagram: 'calferran',
  city: 'Barcelona',
  region: null,
  country: 'Spain',
  createdBy: 'u1',
  updatedAt: '2026-09-27T10:00:00.000Z',
  deletedAt: '2026-09-27T11:00:00.000Z',
);

RemoteVisit visit() => RemoteVisit(
  id: 'v1',
  groupId: 'g1',
  restaurantId: 'r1',
  visitDate: 1700000000000,
  rating: 4,
  notes: 'nice',
  priceRange: 2,
  createdBy: 'u1',
  updatedAt: '2026-09-27T10:00:00.000Z',
  deletedAt: null,
);

void main() {
  test('restaurantToJson uses the remote column names and omits updated_at', () {
    final Map<String, dynamic> json = restaurantToJson(restaurant());

    expect(json['id'], 'r1');
    expect(json['group_id'], 'g1');
    expect(json['cuisineType'], 'italian');
    expect(json['priceRange'], 2);
    expect(json['created_by'], 'u1');
    expect(json['deleted_at'], '2026-09-27T11:00:00.000Z');
    expect(json.containsKey('updated_at'), isFalse);
    expect(json.containsKey('updatedAt'), isFalse);
  });

  test('restaurantFromJson parses the server columns back, including updated_at', () {
    final Map<String, dynamic> json = <String, dynamic>{
      ...restaurantToJson(restaurant()),
      'updated_at': '2026-09-27T10:00:00.000Z',
    };

    final RemoteRestaurant parsed = restaurantFromJson(json);

    expect(parsed.id, 'r1');
    expect(parsed.groupId, 'g1');
    expect(parsed.cuisineType, 'italian');
    expect(parsed.priceRange, 2);
    expect(parsed.region, isNull);
    expect(parsed.updatedAt, '2026-09-27T10:00:00.000Z');
    expect(parsed.deletedAt, '2026-09-27T11:00:00.000Z');
  });

  test('a nullable deleted_at and a DateTime updated_at are both handled', () {
    final Map<String, dynamic> json = <String, dynamic>{
      ...restaurantToJson(restaurant()),
      'deleted_at': null,
      'updated_at': DateTime.utc(2026, 9, 27, 10),
    };

    final RemoteRestaurant parsed = restaurantFromJson(json);

    expect(parsed.deletedAt, isNull);
    expect(parsed.updatedAt, '2026-09-27T10:00:00.000Z');
  });

  test('visitToJson and visitFromJson map the visit columns', () {
    final Map<String, dynamic> json = visitToJson(visit());
    expect(json['restaurant_id'], 'r1');
    expect(json['visitDate'], 1700000000000);
    expect(json['rating'], 4);
    expect(json.containsKey('updated_at'), isFalse);

    final RemoteVisit parsed = visitFromJson(<String, dynamic>{
      ...json,
      'updated_at': '2026-09-27T10:00:00.000Z',
    });
    expect(parsed.id, 'v1');
    expect(parsed.restaurantId, 'r1');
    expect(parsed.notes, 'nice');
    expect(parsed.deletedAt, isNull);
    expect(parsed.updatedAt, '2026-09-27T10:00:00.000Z');
  });

  test('a non-string, non-DateTime timestamp is rejected, not coerced', () {
    final Map<String, dynamic> json = <String, dynamic>{
      ...restaurantToJson(restaurant()),
      'updated_at': 12345,
    };
    expect(() => restaurantFromJson(json), throwsA(isA<SyncException>()));
  });
}
