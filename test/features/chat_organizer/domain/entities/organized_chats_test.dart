import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organized_chats.dart';

void main() {
  final now = DateTime.utc(2026, 3, 10);

  ChatEntity chat(
    String id, {
    int unread = 0,
    ChatType type = ChatType.group,
  }) => ChatEntity(
    id: id,
    seqCounter: 1,
    lastActivityAt: now,
    type: type,
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

  final chats = [
    chat('a'),
    chat('b', unread: 3),
    chat('c', type: ChatType.direct),
    chat('d', unread: 5),
  ];

  ChatRuleContext contextFor(ChatOrganizerData data) => ChatRuleContext(
    now: now,
    myUserId: 7,
    pinnedChatIds: data.pinnedChatIds,
  );

  OrganizedChats organize(ChatOrganizerData data, {ChatFolder? folder}) =>
      organizeChats(
        chats: chats,
        organizer: data,
        context: contextFor(data),
        folder: folder,
      );

  test('with nothing flagged everything stays in one block, in order', () {
    final sections = organize(const ChatOrganizerData());

    expect(sections.pinned, isEmpty);
    expect(sections.archived, isEmpty);
    expect(sections.active.map((c) => c.id), ['a', 'b', 'c', 'd']);
  });

  test('pinned chats are lifted out but keep the server order', () {
    final sections = organize(
      const ChatOrganizerData(pinnedChatIds: {'c', 'a'}),
    );

    expect(sections.pinned.map((c) => c.id), ['a', 'c']);
    expect(sections.active.map((c) => c.id), ['b', 'd']);
    expect(sections.visible.map((c) => c.id), ['a', 'c', 'b', 'd']);
  });

  test('archiving wins over pinning', () {
    final sections = organize(
      const ChatOrganizerData(
        pinnedChatIds: {'a'},
        archivedChatIds: {'a'},
      ),
    );

    expect(sections.pinned, isEmpty);
    expect(sections.archived.map((c) => c.id), ['a']);
  });

  test('the archive badge counts unread, skipping silenced chats', () {
    const data = ChatOrganizerData(archivedChatIds: {'b', 'd'});
    final sections = organize(data);

    expect(sections.unreadInArchive(const {'d'}), 3);
  });

  test('a list with rows only in the archive is not empty, just not visible', () {
    final sections = organizeChats(
      chats: [chat('a')],
      organizer: const ChatOrganizerData(archivedChatIds: {'a'}),
      context: contextFor(const ChatOrganizerData()),
    );

    expect(sections.isEmpty, isFalse);
    expect(sections.visible, isEmpty);
    expect(sections.hasArchive, isTrue);
  });

  group('with a folder selected', () {
    final unread = ChatFolder.fromPreset(FolderPreset.unread);

    test('the list and the pinned zone are both narrowed', () {
      final sections = organize(
        const ChatOrganizerData(pinnedChatIds: {'a', 'd'}),
        folder: unread,
      );

      expect(sections.pinned.map((c) => c.id), ['d']);
      expect(sections.active.map((c) => c.id), ['b']);
    });

    test('the archive is left whole, since a tab should not hide half of it', () {
      final sections = organize(
        const ChatOrganizerData(archivedChatIds: {'a', 'b'}),
        folder: unread,
      );

      expect(sections.archived.map((c) => c.id), ['a', 'b']);
    });

    test('a folder nothing matches leaves the visible list empty', () {
      final sections = organize(
        const ChatOrganizerData(),
        folder: ChatFolder.fromPreset(FolderPreset.channels),
      );

      expect(sections.visible, isEmpty);
    });
  });

  group('folder counts', () {
    final data = ChatOrganizerData(
      folders: [
        ChatFolder.fromPreset(FolderPreset.unread),
        ChatFolder.fromPreset(FolderPreset.personal),
      ],
    );

    test('add up the unread behind each tab', () {
      final counts = folderUnreadCounts(
        chats: chats,
        organizer: data,
        context: contextFor(data),
      );

      expect(counts[FolderPreset.unread.folderId], 8);
      expect(counts[FolderPreset.personal.folderId], 0);
    });

    test('skip what is archived or silenced, which is not asking to be read', () {
      final withArchive = ChatOrganizerData(
        folders: data.folders,
        archivedChatIds: const {'d'},
      );

      final counts = folderUnreadCounts(
        chats: chats,
        organizer: withArchive,
        context: contextFor(withArchive),
        mutedChatIds: const {'b'},
      );

      expect(counts[FolderPreset.unread.folderId], 0);
    });
  });
}
