import 'dart:convert';
import 'dart:io';

import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/share/restaurant_import_reader.dart';
import 'package:eatapp/data/share/restaurant_share_models.dart';
import 'package:eatapp/features/import_export/import_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late Directory dir;

  setUp(() async {
    db = AppDatabase.memory();
    repository = RestaurantRepository(db);
    dir = await Directory.systemTemp.createTemp('eatapp_import_test');
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  Future<String> sharedFile(List<Map<String, Object?>> restaurants) async {
    final File file = File('${dir.path}${Platform.pathSeparator}share.eatapp');
    await file.writeAsString(
      jsonEncode(<String, Object?>{
        'format': restaurantShareFormat,
        'restaurants': restaurants,
      }),
    );
    return file.path;
  }

  Map<String, Object?> row(
    String name, {
    String? street,
    int priceRange = 2,
    List<Map<String, Object?>> visits = const <Map<String, Object?>>[],
  }) => <String, Object?>{
    'name': name,
    'cuisineType': 'italian',
    'priceRange': priceRange,
    'streetAddress': street,
    'visits': visits,
  };

  test('a new file loads as add candidates', () async {
    final String path = await sharedFile(<Map<String, Object?>>[
      row('Trattoria'),
    ]);
    final ImportController controller = ImportController(
      repository: repository,
      filePath: path,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.error, isNull);
    expect(controller.state.candidates, hasLength(1));
    expect(controller.state.candidates.single.decision, ImportDecision.add);
    expect(controller.state.candidates.single.duplicateOf, isNull);
  });

  test('a likely duplicate is flagged and defaults to skip', () async {
    await repository.insert(
      restaurant(id: 'existing', name: 'Cal Ferran', streetAddress: 'Plaça'),
    );
    final String path = await sharedFile(<Map<String, Object?>>[
      row('Cal Ferran', street: 'Plaça'),
    ]);
    final ImportController controller = ImportController(
      repository: repository,
      filePath: path,
    );
    addTearDown(controller.dispose);

    await controller.load();

    final ImportCandidate candidate = controller.state.candidates.single;
    expect(candidate.duplicateOf?.id, 'existing');
    expect(candidate.decision, ImportDecision.skip);
  });

  test('confirm adds the rows together with their visits', () async {
    final String path = await sharedFile(<Map<String, Object?>>[
      row(
        'Trattoria',
        visits: <Map<String, Object?>>[
          <String, Object?>{
            'visitDate': 1000,
            'rating': 5,
            'notes': 'great',
            'priceRange': 2,
          },
        ],
      ),
    ]);
    final ImportController controller = ImportController(
      repository: repository,
      filePath: path,
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.confirm();

    final List<Restaurant> all = await repository.getAllRestaurants();
    expect(all, hasLength(1));
    expect(all.single.name, 'Trattoria');
    final List<Visit> visits = await repository
        .observeVisitsForRestaurant(all.single.id)
        .first;
    expect(visits, hasLength(1));
    expect(visits.single.rating, 5);
    expect(visits.single.notes, 'great');
  });

  test('replace edits the existing row in place, keeping its id', () async {
    await repository.insert(
      restaurant(id: 'existing', name: 'Cal Ferran', priceRange: 1),
    );
    final String path = await sharedFile(<Map<String, Object?>>[
      row('Cal Ferran', priceRange: 3),
    ]);
    final ImportController controller = ImportController(
      repository: repository,
      filePath: path,
    );
    addTearDown(controller.dispose);

    await controller.load();
    controller.onDecisionChange(0, ImportDecision.replace);
    await controller.confirm();

    final List<Restaurant> all = await repository.getAllRestaurants();
    expect(all, hasLength(1));
    expect(all.single.id, 'existing');
    expect(all.single.priceRange, 3);
  });

  test('an invalid file reports an invalid-file error', () async {
    final File file = File('${dir.path}${Platform.pathSeparator}bad.eatapp');
    await file.writeAsString('{"format":"not-ours","restaurants":[]}');
    final ImportController controller = ImportController(
      repository: repository,
      filePath: file.path,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.error, ImportFailureReason.invalidFile);
    expect(controller.state.candidates, isEmpty);
  });

  test('a valid but empty file loads with no candidates and no error', () async {
    final String path = await sharedFile(<Map<String, Object?>>[]);
    final ImportController controller = ImportController(
      repository: repository,
      filePath: path,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.error, isNull);
    expect(controller.state.candidates, isEmpty);
  });

  test('a missing file reports an IO error', () async {
    final ImportController controller = ImportController(
      repository: repository,
      filePath: '${dir.path}${Platform.pathSeparator}missing.eatapp',
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.error, ImportFailureReason.ioError);
  });
}
