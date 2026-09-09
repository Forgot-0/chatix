import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/direct_chat_lookup.dart';

void main() {
  const me = 7;
  const peer = 42;
  const stranger = 99;

  ChatProfileEntity profile(int userId) => ChatProfileEntity(
    userId: userId,
    username: 'u$userId',
    displayName: 'User $userId',
    avatarUrl: null,
    avatarS3Key: null,
  );

  ChatMemberEntity member(int userId) => ChatMemberEntity(
    userId: userId,
    roleId: 4,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
    profile: profile(userId),
  );

  MessageEntity lastMessage(int authorId) => MessageEntity(
    id: 'm1',
    chatId: 'c',
    seq: 1,
    authorId: authorId,
    type: MessageType.text,
    content: 'hi',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 1, 1),
    attachments: const [],
    profile: profile(authorId),
  );

  ChatEntity chat({
    required String id,
    ChatType type = ChatType.direct,
    List<ChatMemberEntity>? members,
    MessageEntity? last,
  }) => ChatEntity(
    id: id,
    seqCounter: 1,
    lastActivityAt: null,
    type: type,
    name: null,
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: me,
    memberCount: 2,
    members: members,
    lastMessage: last,
  );

  group('findDirectChatWith — roster', () {
    test('finds the 1:1 chat that has the peer on its roster', () {
      final target = chat(id: 'a', members: [member(me), member(peer)]);
      final other = chat(id: 'b', members: [member(me), member(stranger)]);

      expect(findDirectChatWith([other, target], peer, myUserId: me), target);
    });

    test('returns null when nobody matches', () {
      final other = chat(id: 'b', members: [member(me), member(stranger)]);

      expect(findDirectChatWith([other], peer, myUserId: me), isNull);
    });
  });

  group('findDirectChatWith — list rows without a roster', () {
    test('falls back to the last message author', () {
      final target = chat(id: 'a', last: lastMessage(peer));

      expect(findDirectChatWith([target], peer, myUserId: me), target);
    });

    test('my own last message proves nothing about the peer', () {
      // The only profile on the row is mine, so the counterpart is unknown —
      // guessing here would silently reuse the wrong chat.
      final ambiguous = chat(id: 'a', last: lastMessage(me));

      expect(findDirectChatWith([ambiguous], peer, myUserId: me), isNull);
    });
  });

  group('findDirectChatWith — guards', () {
    test('never matches a group, supergroup or channel', () {
      for (final type in [
        ChatType.group,
        ChatType.supergroup,
        ChatType.channel,
      ]) {
        final group = chat(
          id: 'g',
          type: type,
          members: [member(me), member(peer)],
        );
        expect(
          findDirectChatWith([group], peer, myUserId: me),
          isNull,
          reason: '$type',
        );
      }
    });

    test('an empty list is simply a miss', () {
      expect(findDirectChatWith(const [], peer, myUserId: me), isNull);
    });

    test('a roster without the peer does not fall through to last_message', () {
      // The roster is authoritative: if the peer is not on it, this is not the
      // chat, whatever the last message happens to say.
      final misleading = chat(
        id: 'a',
        members: [member(me), member(stranger)],
        last: lastMessage(peer),
      );

      expect(findDirectChatWith([misleading], peer, myUserId: me), isNull);
    });

    test('a roster that lists only me is a miss, not a last_message guess', () {
      // A partial roster is the case where the two sources genuinely disagree:
      // the roster says the peer is not here, `last_message` says they wrote
      // the newest message. The roster wins, otherwise an unrelated chat gets
      // silently reused as the 1:1 with this person.
      final partial = chat(
        id: 'a',
        members: [member(me)],
        last: lastMessage(peer),
      );

      expect(findDirectChatWith([partial], peer, myUserId: me), isNull);
    });

    test('returns the first match when duplicates already exist', () {
      // Duplicates are exactly what this guard exists to stop creating more of,
      // but old ones may already be there.
      final first = chat(id: 'a', members: [member(me), member(peer)]);
      final second = chat(id: 'b', members: [member(me), member(peer)]);

      expect(findDirectChatWith([first, second], peer, myUserId: me), first);
    });
  });
}
