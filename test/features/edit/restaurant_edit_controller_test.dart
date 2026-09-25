import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/features/edit/restaurant_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';

Future<void> waitFor(
  bool Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) {
      fail('timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late List<RestaurantEditController> controllers;

  RestaurantEditController buildController({String? restaurantId}) {
    final RestaurantEditController controller = RestaurantEditController(
      repository: repository,
      restaurantId: restaurantId,
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    controllers = <RestaurantEditController>[];
  });

  tearDown(() async {
    for (final RestaurantEditController controller in controllers) {
      controller.dispose();
    }
    await db.close();
  });

  test('refuses an empty form, flagging the name and the cuisine', () async {
    final RestaurantEditController controller = buildController();

    expect(await controller.save(), isFalse);
    expect(controller.state.nameError, isTrue);
    expect(controller.state.cuisineError, isTrue);
    expect(await repository.observeFiltered().first, isEmpty);
  });

  test('inserts a new restaurant with its tags and a searchable column',
      () async {
    final RestaurantEditController controller = buildController();
    controller.onNameChange('  Kebab House  ');
    controller.onCuisineChange('turkish');
    controller.onCityChange('Mataró');
    controller.addTag('Terraza');

    expect(await controller.save(), isTrue);

    final List<Restaurant> rows = await db.restaurantDao.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Kebab House', reason: 'the name is trimmed');
    expect(
      await repository.observeTagNames(rows.single.id).first,
      <String>['Terraza'],
    );
    expect(
      await filteredIds(db, query: 'kebab'),
      <String>[rows.single.id],
      reason: 'the derived search column finds it',
    );
  });

  test('normalizes a bare host and a leading @, rejecting neither', () async {
    final RestaurantEditController controller = buildController();
    controller.onNameChange('Cal Ferran');
    controller.onCuisineChange('mediterranean');
    controller.onWebsiteChange('calferran.example');
    controller.onInstagramChange('@calferran');

    expect(await controller.save(), isTrue);

    final Restaurant row = (await db.restaurantDao.getAll()).single;
    expect(row.website, 'https://calferran.example');
    expect(row.instagram, 'calferran');
  });

  test('flags a website that is not a web address', () async {
    final RestaurantEditController controller = buildController();
    controller.onNameChange('Cal Ferran');
    controller.onCuisineChange('mediterranean');
    controller.onWebsiteChange('javascript:alert(1)');

    expect(await controller.save(), isFalse);
    expect(controller.state.websiteError, isTrue);
    expect(await repository.observeFiltered().first, isEmpty);
  });

  test('a tag that is blank, comma-carrying or a duplicate is not added',
      () async {
    final RestaurantEditController controller = buildController();

    controller.addTag('   ');
    controller.addTag('Terraza, Grupos');
    controller.addTag('Terraza');
    controller.addTag('terraza');

    expect(controller.state.tags, <String>['Terraza']);
  });

  test('preloads an existing restaurant and updates it', () async {
    await repository.insert(
      restaurant(
        id: 'a',
        name: 'Cal Ferran',
        cuisineType: 'mediterranean',
        city: 'Mataró',
      ),
      tags: <String>['Terraza'],
    );

    final RestaurantEditController controller = buildController(restaurantId: 'a');
    await waitFor(
      () => !controller.state.isLoading,
      description: 'the restaurant to load into the form',
    );

    expect(controller.state.name, 'Cal Ferran');
    expect(controller.state.cuisineType, 'mediterranean');
    expect(controller.state.city, 'Mataró');
    expect(controller.state.tags, <String>['Terraza']);

    controller.onNameChange('Cal Ferran Nou');
    expect(await controller.save(), isTrue);

    final List<Restaurant> rows = await db.restaurantDao.getAll();
    expect(rows, hasLength(1), reason: 'an edit does not insert a second row');
    expect(rows.single.id, 'a');
    expect(rows.single.name, 'Cal Ferran Nou');
    expect(await filteredIds(db, query: 'nou'), <String>['a']);
  });
}
