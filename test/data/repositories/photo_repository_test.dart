import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/photo_repository.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/write_effects.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/db_test_utils.dart';

/// [PhotoRepository] on its own — constructed directly with a bare
/// [WriteEffects], rather than reached through [RestaurantRepository], to
/// prove the split genuinely stands alone.
void main() {
  late AppDatabase db;
  late PhotoRepository photos;

  setUp(() async {
    db = createTestDatabase();
    final WriteEffects effects = WriteEffects(
      db,
      exportAll: () async => const <RestaurantExport>[],
    );
    photos = PhotoRepository(db, effects);
    await RestaurantRepository(db).insert(restaurant(id: 'a', name: 'First'));
  });

  tearDown(() => db.close());

  test('setRestaurantPhoto stores it, then clears it with null', () async {
    await photos.setRestaurantPhoto('a', '/photos/a.jpg');
    expect(await photos.getRestaurantPhotoPath('a'), '/photos/a.jpg');

    await photos.setRestaurantPhoto('a', null);
    expect(await photos.getRestaurantPhotoPath('a'), isNull);
  });
}
