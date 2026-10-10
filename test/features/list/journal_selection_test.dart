import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/data/supabase/identity.dart';
import 'package:eatapp/features/groups/groups_controller.dart';
import 'package:eatapp/features/list/journal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/groups/fake_group_gateway.dart';
import '../../data/photo/photo_fakes.dart';
import '../../data/supabase/fake_identity_gateway.dart';

/// The Journal's selection mode: a long press ticks restaurants, and the
/// contextual bar's "Add to group" shares them all in one go.
void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late UserPreferencesRepository preferences;

  // Seeded here rather than in the test body: a drift write awaited under the
  // fake clock a `testWidgets` body runs on never completes.
  setUp(() async {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
    await repository.insert(restaurant(id: 'a', name: 'Kebab'));
    await repository.insert(restaurant(id: 'b', name: 'Sushi'));
    await repository.insert(restaurant(id: 'c', name: 'Tacos'));
  });

  tearDown(() => db.close());

  Future<GroupsController> ready() async {
    final GroupsController controller = GroupsController(
      preferences: preferences,
      gateway: FakeGroupGateway(
        groups: const <Group>[
          Group(id: 'g1', name: 'Família', role: GroupRole.owner),
          Group(id: 'g2', name: 'Amics', role: GroupRole.editor),
          Group(id: 'g3', name: 'Feina', role: GroupRole.reader),
        ],
      ),
      identity: FakeIdentityGateway(existingUserId: 'u1'),
    );
    addTearDown(controller.dispose);
    await controller.load();
    return controller;
  }

  Widget host({GroupsController? groups, IdentityGateway? identity}) =>
      AppScope(
        restaurants: repository,
        preferences: preferences,
        photoPicker: FakePhotoPicker(),
        identity: identity,
        groupsController: groups,
        child: MaterialApp(
          theme: AppTheme.of(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: JournalScreen(onOpenRestaurant: (_) {}),
        ),
      );

  /// Hand-pumped: the initial-load skeletons pulse forever, and the database's
  /// answers live on the real event loop, which only `runAsync` reaches.
  Future<void> pump(WidgetTester tester) async {
    for (int round = 0; round < 3; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('ticked restaurants are added to the chosen group', (
    WidgetTester tester,
  ) async {
    tallView(tester);
    final GroupsController groups = await ready();
    await tester.pumpWidget(
      host(groups: groups, identity: FakeIdentityGateway(existingUserId: 'u1')),
    );
    await pump(tester);

    await tester.longPress(find.text('Kebab'));
    await pump(tester);
    expect(find.text('1 selected'), findsOneWidget);

    // In selection mode a tap ticks rather than opening the restaurant.
    await tester.tap(find.text('Sushi'));
    await pump(tester);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to group'));
    await pump(tester);
    // A reader can't share into a group, so it isn't offered.
    expect(find.widgetWithText(CheckboxListTile, 'Família'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Amics'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Feina'), findsNothing);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Família'));
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await pump(tester);

    expect(find.text('2 restaurants added'), findsOneWidget);
    expect(find.text('2 selected'), findsNothing);
    final Set<String>? shared = await tester.runAsync(
      () async => <String>{
        for (final String id in <String>['a', 'b', 'c'])
          if ((await repository.groupIdsForRestaurant(id)).contains('g1')) id,
      },
    );
    expect(shared, <String>{'a', 'b'});

    await disposeApp(tester);
  });

  testWidgets('the close button leaves selection mode', (
    WidgetTester tester,
  ) async {
    tallView(tester);
    final GroupsController groups = await ready();
    await tester.pumpWidget(host(groups: groups));
    await pump(tester);

    await tester.longPress(find.text('Kebab'));
    await pump(tester);
    await tester.tap(find.byTooltip('Cancel selection'));
    await pump(tester);

    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Restaurants'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('without groups a long press does not start a selection', (
    WidgetTester tester,
  ) async {
    tallView(tester);
    await tester.pumpWidget(host());
    await pump(tester);

    await tester.longPress(find.text('Kebab'));
    await pump(tester);

    expect(find.text('1 selected'), findsNothing);

    await disposeApp(tester);
  });
}
