import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_search.dart';

void main() {
  const myUserId = 7;

  ChatEntity chat(
    String id, {
    String? name,
    String? description,
    ChatType type = ChatType.group,
    List<ChatMemberEntity>? members,
  }) => ChatEntity(
    id: id,
    seqCounter: 1,
    lastActivityAt: DateTime.utc(2026, 3, 10),
    type: type,
    name: name,
    description: description,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 2,
    members: members,
  );

  ChatMemberEntity member(int userId, String displayName) => ChatMemberEntity(
    userId: userId,
    roleId: 4,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
    profile: ChatProfileEntity(
      userId: userId,
      username: 'user$userId',
      displayName: displayName,
      avatarUrl: null,
      avatarS3Key: null,
    ),
  );

  test('an empty query matches nothing at all', () {
    expect(searchLoadedChats([chat('a', name: 'Design')], ' '), isEmpty);
  });

  test('finds a chat by name, ignoring case', () {
    final hits = searchLoadedChats([chat('a', name: 'Design team')], 'DESIGN');

    expect(hits, hasLength(1));
    expect(hits.single.field, ChatMatchField.title);
    expect(hits.single.matchedText, 'Design team');
  });

  test('finds a direct chat by the other person', () {
    final direct = chat(
      'a',
      type: ChatType.direct,
      members: [member(myUserId, 'Me'), member(9, 'Ann Lee')],
    );

    final hits = searchLoadedChats([direct], 'ann', myUserId: myUserId);

    expect(hits.single.field, ChatMatchField.peer);
    expect(hits.single.matchedText, 'Ann Lee');
  });

  test('finds a chat by description and says that is what matched', () {
    final hits = searchLoadedChats([
      chat('a', name: 'Random', description: 'Weekly design review'),
    ], 'design');

    expect(hits.single.field, ChatMatchField.description);
    expect(hits.single.isTitleMatch, isFalse);
  });

  test('name matches come before description matches', () {
    final chats = [
      chat('a', name: 'Random', description: 'about design'),
      chat('b', name: 'Design team'),
      chat('c', name: 'Offsite', description: 'design sprint'),
    ];

    final hits = searchLoadedChats(chats, 'design');

    expect(hits.map((h) => h.chat.id), ['b', 'a', 'c']);
  });

  test('a chat is reported once, on its strongest match', () {
    final hits = searchLoadedChats([
      chat('a', name: 'Design', description: 'design, design, design'),
    ], 'design');

    expect(hits, hasLength(1));
    expect(hits.single.field, ChatMatchField.title);
  });

  test('the last message is not searched here', () {
    // That is the messages tab's job; a chat row matching on something the
    // row does not show reads as a bug.
    final hits = searchLoadedChats([chat('a', name: 'Design team')], 'ship');

    expect(hits, isEmpty);
  });

  test('a chat that matches nothing stays out', () {
    expect(
      searchLoadedChats([chat('a', name: 'Design')], 'marketing'),
      isEmpty,
    );
  });
}
