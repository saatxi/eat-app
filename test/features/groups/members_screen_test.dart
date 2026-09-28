import 'package:eatapp/app/app_scope.dart';
import 'package:eatapp/core/l10n/generated/app_localizations.dart';
import 'package:eatapp/core/theme/app_theme.dart';
import 'package:eatapp/data/db/app_database.dart';
import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:eatapp/data/repositories/restaurant_repository.dart';
import 'package:eatapp/data/repositories/user_preferences_repository.dart';
import 'package:eatapp/features/groups/members_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/db/db_test_utils.dart';
import '../../data/photo/photo_fakes.dart';
import '../../data/supabase/fake_identity_gateway.dart';

/// A hand-written [GroupGateway] fake covering the roster and the rename call.
class _FakeGroupGateway implements GroupGateway {
  _FakeGroupGateway({this.members = const <GroupMember>[]});

  List<GroupMember> members;

  /// The display names [setDisplayName] stored, keyed by user id.
  final Map<String, String> names = <String, String>{};

  @override
  Future<List<GroupMember>> listMembers(String groupId) async => members;

  @override
  Future<void> setDisplayName({
    required String userId,
    required String displayName,
  }) async {
    names[userId] = displayName;
    members = <GroupMember>[
      for (final GroupMember member in members)
        if (member.userId == userId)
          GroupMember(
            userId: member.userId,
            displayName: displayName,
            role: member.role,
          )
        else
          member,
    ];
  }

  @override
  Future<Group> createGroup({
    required String id,
    required String name,
    required String createdBy,
  }) async => throw UnimplementedError();

  @override
  Future<List<Group>> listGroups(String userId) async => const <Group>[];

  @override
  Future<void> leaveGroup(String groupId, String userId) async {}

  @override
  Future<void> removeMember(String groupId, String userId) async {}

  @override
  Future<void> deleteGroup(String groupId) async {}
}

void main() {
  late AppDatabase db;
  late RestaurantRepository repository;
  late UserPreferencesRepository preferences;

  setUp(() {
    db = createTestDatabase();
    repository = RestaurantRepository(db);
    preferences = UserPreferencesRepository();
  });

  tearDown(() => db.close());

  Widget host({required GroupGateway groups, required Widget child}) => AppScope(
    restaurants: repository,
    preferences: preferences,
    photoPicker: FakePhotoPicker(),
    groups: groups,
    identity: FakeIdentityGateway(existingUserId: 'u1'),
    child: MaterialApp(
      theme: AppTheme.of(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );

  testWidgets('your own row can be given a display name', (
    WidgetTester tester,
  ) async {
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: '', role: GroupRole.owner),
      ],
    );
    const Group group = Group(id: 'g1', name: 'Família', role: GroupRole.owner);

    await tester.pumpWidget(
      host(groups: gateway, child: const MembersScreen(group: group)),
    );
    await tester.pumpAndSettle();

    // With no name set, the row falls back to the bare user id.
    expect(find.textContaining('u1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Albert');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(gateway.names, <String, String>{'u1': 'Albert'});
    expect(find.textContaining('Albert'), findsOneWidget);
    expect(find.textContaining('u1'), findsNothing);
  });

  testWidgets('the rename dialog refuses an empty name', (
    WidgetTester tester,
  ) async {
    final _FakeGroupGateway gateway = _FakeGroupGateway(
      members: const <GroupMember>[
        GroupMember(userId: 'u1', displayName: 'Albert', role: GroupRole.owner),
      ],
    );
    const Group group = Group(id: 'g1', name: 'Família', role: GroupRole.owner);

    await tester.pumpWidget(
      host(groups: gateway, child: const MembersScreen(group: group)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // The dialog stays open with the error; nothing was written.
    expect(find.text('Enter a name'), findsOneWidget);
    expect(gateway.names, isEmpty);
  });
}
