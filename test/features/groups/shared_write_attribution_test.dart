import 'package:drift/drift.dart' show Value;
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/data/sync/pending_sync_store.dart';
import 'package:eatapp/data/sync/shared_write.dart';
import 'package:eatapp/data/sync/shared_writes.dart';
import 'package:eatapp/data/sync/sync_table.dart';
import 'package:eatapp/features/edit/restaurant_edit_controller.dart';
import 'package:eatapp/features/log_visit/log_visit_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/supabase/fake_identity_gateway.dart';

/// The write side of the group contract, as the screens drive it: a form's save
/// carries the selected group (for a new restaurant) or the row's own group (for
/// an edit and for children), and a Personal save carries neither.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late UserPreferencesRepository preferences;
  late FakeIdentityGateway identity;
  late SharedWrites sharedWrites;
  late PendingSyncStore pending;

  const String teamGroupId = 'g1';
  const String teamUserId = 'u1';

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
    identity = FakeIdentityGateway(existingUserId: teamUserId);
    sharedWrites = SharedWrites(
      preferences: preferences,
      identity: identity,
    );
    pending = PendingSyncStore(db);
  });

  tearDown(() => db.close());

  Restaurant sharedRow({String id = 'r1', String name = 'Shared'}) =>
      restaurant(id: id, name: name).copyWith(
        groupId: Value<String?>(teamGroupId),
        createdBy: Value<String?>(teamUserId),
      );

  group('SharedWrites', () {
    test('resolves nothing in Personal mode', () async {
      expect(await sharedWrites.forNewRow(), isNull);
    });

    test('resolves the selected group and the current user', () async {
      await preferences.setSelectedGroup(teamGroupId);

      final SharedWrite? shared = await sharedWrites.forNewRow();

      expect(shared, isNotNull);
      expect(shared!.groupId, teamGroupId);
      expect(shared.createdBy, teamUserId);
    });

    test('a private parent stays private, even with a group selected', () async {
      await preferences.setSelectedGroup(teamGroupId);

      expect(await sharedWrites.forChildOf(null), isNull);
    });
  });

  group('the edit form', () {
    test('adding in a group stamps and queues the restaurant', () async {
      await preferences.setSelectedGroup(teamGroupId);
      final RestaurantEditController controller = RestaurantEditController(
        repository: repository,
        sharedWrites: sharedWrites,
      );
      addTearDown(controller.dispose);

      controller.onNameChange('Nova');
      controller.onCuisineChange('italian');
      expect(await controller.save(), isTrue);

      final Restaurant row = await db.select(db.restaurants).getSingle();
      expect(row.groupId, teamGroupId);
      expect(row.createdBy, teamUserId);
      expect(
        (await pending.pendingForGroup(teamGroupId)).single.sharedTable,
        SyncTable.restaurants.name,
      );
    });

    test('editing a shared row keeps its group and its original author', () async {
      await repository.insert(sharedRow(name: 'Old'));
      await preferences.setSelectedGroup(teamGroupId);
      final RestaurantEditController controller = RestaurantEditController(
        repository: repository,
        restaurantId: 'r1',
        sharedWrites: sharedWrites,
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      controller.onNameChange('New');
      expect(await controller.save(), isTrue);

      final Restaurant row = await db.select(db.restaurants).getSingle();
      expect(row.name, 'New');
      expect(row.groupId, teamGroupId, reason: 'editing must not blank the sharing');
      expect(row.createdBy, teamUserId);
    });

    test('a Personal add stays private and unqueued', () async {
      final RestaurantEditController controller = RestaurantEditController(
        repository: repository,
        sharedWrites: sharedWrites,
      );
      addTearDown(controller.dispose);

      controller.onNameChange('Private');
      controller.onCuisineChange('italian');
      expect(await controller.save(), isTrue);

      final Restaurant row = await db.select(db.restaurants).getSingle();
      expect(row.groupId, isNull);
      expect(row.createdBy, isNull);
      expect(await pending.pendingForGroup(teamGroupId), isEmpty);
    });
  });

  group('the log-visit form', () {
    test("a visit on a shared restaurant takes the restaurant's group", () async {
      await repository.insert(sharedRow());
      final LogVisitController controller = LogVisitController(
        repository: repository,
        restaurantId: 'r1',
        sharedWrites: sharedWrites,
      );
      addTearDown(controller.dispose);

      controller.onRatingChange(5);
      await controller.save();

      final Visit visit = await db.select(db.visits).getSingle();
      expect(visit.groupId, teamGroupId);
      expect(visit.createdBy, teamUserId);
      expect(
        (await pending.pendingForGroup(teamGroupId))
            .where((PendingSync e) => e.sharedTable == SyncTable.visits.name),
        hasLength(1),
      );
    });

    test('a visit on a private restaurant stays private', () async {
      await repository.insert(restaurant(id: 'p', name: 'Private'));
      await preferences.setSelectedGroup(teamGroupId);
      final LogVisitController controller = LogVisitController(
        repository: repository,
        restaurantId: 'p',
        sharedWrites: sharedWrites,
      );
      addTearDown(controller.dispose);

      controller.onRatingChange(4);
      await controller.save();

      final Visit visit = await db.select(db.visits).getSingle();
      expect(visit.groupId, isNull);
      expect(await pending.pendingForGroup(teamGroupId), isEmpty);
    });
  });
}
