import 'package:eatapp/data/groups/group_gateway.dart';
import 'package:eatapp/data/groups/group_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupRole', () {
    test('round-trips to and from the stored value', () {
      expect(GroupRole.owner.remote, 'owner');
      expect(GroupRole.editor.remote, 'editor');
      expect(GroupRole.reader.remote, 'reader');
      expect(GroupRole.fromRemote('owner'), GroupRole.owner);
      expect(GroupRole.fromRemote('editor'), GroupRole.editor);
      expect(GroupRole.fromRemote('reader'), GroupRole.reader);
    });

    test('reads the pre-roles member value as an editor', () {
      expect(GroupRole.fromRemote('member'), GroupRole.editor);
    });

    test('splits write and management capabilities by role', () {
      expect(GroupRole.owner.canEdit, isTrue);
      expect(GroupRole.owner.canManage, isTrue);
      expect(GroupRole.editor.canEdit, isTrue);
      expect(GroupRole.editor.canManage, isFalse);
      expect(GroupRole.reader.canEdit, isFalse);
      expect(GroupRole.reader.canManage, isFalse);
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
      'role': 'editor',
      'display_name': 'Maria',
    });

    expect(member.userId, 'u2');
    expect(member.displayName, 'Maria');
    expect(member.role, GroupRole.editor);
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
