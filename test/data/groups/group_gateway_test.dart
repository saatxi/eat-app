import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupRole', () {
    test('round-trips to and from the stored value', () {
      expect(GroupRole.owner.remote, 'owner');
      expect(GroupRole.member.remote, 'member');
      expect(GroupRole.fromRemote('owner'), GroupRole.owner);
      expect(GroupRole.fromRemote('member'), GroupRole.member);
    });

    test('rejects an unknown value rather than guessing', () {
      expect(() => GroupRole.fromRemote('admin'), throwsA(isA<GroupException>()));
    });
  });

  test('groupFromMembershipJson parses an embedded group', () {
    final Group group = groupFromMembershipJson(<String, dynamic>{
      'group_id': 'g1',
      'role': 'owner',
      'groups': <String, dynamic>{'name': 'Família'},
    });

    expect(group.id, 'g1');
    expect(group.name, 'Família');
    expect(group.role, GroupRole.owner);
  });

  test('groupMemberFromRow parses a roster row from the view', () {
    final GroupMember member = groupMemberFromRow(<String, dynamic>{
      'user_id': 'u2',
      'role': 'member',
      'display_name': 'Maria',
    });

    expect(member.userId, 'u2');
    expect(member.displayName, 'Maria');
    expect(member.role, GroupRole.member);
  });

  test('a member with no display name falls back to an empty string', () {
    final GroupMember member = groupMemberFromRow(<String, dynamic>{
      'user_id': 'u3',
      'role': 'owner',
      'display_name': null,
    });

    expect(member.displayName, '');
    expect(member.role, GroupRole.owner);
  });
}
