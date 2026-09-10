import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_list_sections.dart';

void main() {
  ChatEntity chat(String id, {int unread = 0}) => ChatEntity(
    id: id,
    seqCounter: 1,
    lastActivityAt: DateTime.utc(2026, 1, 1),
    type: ChatType.group,
    name: 'Chat $id',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 2,
    unreadCount: unread,
  );

  final chats = [chat('a'), chat('b', unread: 3), chat('c'), chat('d', unread: 5)];

  test('with nothing flagged everything stays in one block, in order', () {
    final sections = splitChatsForList(chats, const ChatLocalPrefs());

    expect(sections.pinned, isEmpty);
    expect(sections.archived, isEmpty);
    expect(sections.active.map((c) => c.id), ['a', 'b', 'c', 'd']);
  });

  test('pinned chats are lifted out but keep the server order', () {
    final sections = splitChatsForList(
      chats,
      const ChatLocalPrefs(pinned: {'c', 'a'}),
    );

    expect(sections.pinned.map((c) => c.id), ['a', 'c']);
    expect(sections.active.map((c) => c.id), ['b', 'd']);
    expect(sections.visible.map((c) => c.id), ['a', 'c', 'b', 'd']);
  });

  test('archiving wins over pinning', () {
    final sections = splitChatsForList(
      chats,
      const ChatLocalPrefs(pinned: {'a'}, archived: {'a'}),
    );

    expect(sections.pinned, isEmpty);
    expect(sections.archived.map((c) => c.id), ['a']);
  });

  test('the archive badge counts unread, skipping silenced chats', () {
    const prefs = ChatLocalPrefs(archived: {'b', 'd'}, muted: {'d'});
    final sections = splitChatsForList(chats, prefs);

    expect(sections.unreadInArchive(prefs), 3);
  });

  test('a list with rows only in the archive is not empty, just not visible', () {
    final sections = splitChatsForList(
      [chat('a')],
      const ChatLocalPrefs(archived: {'a'}),
    );

    expect(sections.isEmpty, isFalse);
    expect(sections.visible, isEmpty);
    expect(sections.hasArchive, isTrue);
  });
}
