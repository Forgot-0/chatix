import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organized_chats.dart';

/// Pins, the archive and silenced chats are fields on the row now
/// (api-docs §5.2), so the sections are read off the chats themselves.
void main() {
  final now = DateTime.utc(2026, 3, 10);

  ChatEntity chat(
    String id, {
    int unread = 0,
    ChatType type = ChatType.group,
    bool pinned = false,
    DateTime? pinnedAt,
    bool archived = false,
    bool muted = false,
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
    state: pinned || archived || muted
        ? ChatStateEntity(
            isPinned: pinned,
            pinnedAt: pinnedAt,
            isArchived: archived,
            isMutedByMe: muted,
          )
        : null,
  );

  final context = ChatRuleContext(now: now, myUserId: 7);

  OrganizedChats organize(List<ChatEntity> chats, {ChatFolder? folder}) =>
      organizeChats(chats: chats, context: context, folder: folder);

  test('with nothing flagged everything stays in one block, in order', () {
    final sections = organize([chat('a'), chat('b'), chat('c')]);

    expect(sections.pinned, isEmpty);
    expect(sections.active.map((c) => c.id), ['a', 'b', 'c']);
  });

  test('pinned chats are lifted out of the list below', () {
    final sections = organize([
      chat('a', pinned: true),
      chat('b'),
      chat('c', pinned: true),
      chat('d'),
    ]);

    expect(sections.pinned.map((c) => c.id), ['a', 'c']);
    expect(sections.active.map((c) => c.id), ['b', 'd']);
    expect(sections.visible.map((c) => c.id), ['a', 'c', 'b', 'd']);
  });

  test('the newest pin sits at the top of the zone', () {
    final sections = organize([
      chat('old', pinned: true, pinnedAt: DateTime.utc(2026, 1, 1)),
      chat('new', pinned: true, pinnedAt: DateTime.utc(2026, 3, 1)),
      chat('middle', pinned: true, pinnedAt: DateTime.utc(2026, 2, 1)),
    ]);

    expect(sections.pinned.map((c) => c.id), ['new', 'middle', 'old']);
  });

  test('a row that says it is archived leaves the screen at once', () {
    // The main list should not be holding one — the archive is a separate
    // set — but one archived a moment ago on this device still is.
    final sections = organize([
      chat('a'),
      chat('b', archived: true),
      chat('c', pinned: true, archived: true),
    ]);

    expect(sections.active.map((c) => c.id), ['a']);
    expect(sections.pinned, isEmpty);
  });

  test('a folder narrows both blocks', () {
    final folder = ChatFolder(
      id: 'f',
      title: 'Direct',
      rules: const [ChatTypeRule({ChatType.direct})],
    );

    final sections = organize([
      chat('a', type: ChatType.direct, pinned: true),
      chat('b', type: ChatType.direct),
      chat('c'),
    ], folder: folder);

    expect(sections.pinned.map((c) => c.id), ['a']);
    expect(sections.active.map((c) => c.id), ['b']);
  });

  group('the archive badge', () {
    test('counts what is unread in there', () {
      expect(
        unreadInArchive([chat('a', unread: 3), chat('b', unread: 5)]),
        8,
      );
    });

    test('leaves out chats that were told to stay quiet', () {
      expect(
        unreadInArchive([
          chat('a', unread: 3),
          chat('b', unread: 5, muted: true),
        ]),
        3,
      );
    });

    test('an empty archive counts nothing', () {
      expect(unreadInArchive(const []), 0);
    });
  });

  group('folder counts', () {
    final folders = [
      ChatFolder(
        id: 'unread',
        title: 'Unread',
        rules: const [UnreadRule()],
      ),
      ChatFolder(
        id: 'direct',
        title: 'Direct',
        rules: const [ChatTypeRule({ChatType.direct})],
      ),
    ];

    Map<String, int> countsFor(List<ChatEntity> chats) => folderUnreadCounts(
      chats: chats,
      folders: folders,
      context: context,
    );

    test('add up what each folder would show', () {
      final counts = countsFor([
        chat('a', unread: 3),
        chat('b', unread: 5, type: ChatType.direct),
        chat('c'),
      ]);

      expect(counts['unread'], 8);
      expect(counts['direct'], 5);
    });

    test('skip silenced chats, which are not asking to be read', () {
      final counts = countsFor([
        chat('a', unread: 3),
        chat('b', unread: 5, muted: true),
      ]);

      expect(counts['unread'], 3);
    });

    test('skip the archive, which the tab would not show anyway', () {
      final counts = countsFor([
        chat('a', unread: 3),
        chat('b', unread: 5, archived: true),
      ]);

      expect(counts['unread'], 3);
    });

    test('a folder nothing matches counts zero rather than going missing', () {
      final counts = countsFor([chat('a')]);

      expect(counts['unread'], 0);
      expect(counts['direct'], 0);
    });
  });
}
