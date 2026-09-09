import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

void main() {
  const myUserId = 7;
  const peerUserId = 42;

  const myProfile = ChatProfileEntity(
    userId: myUserId,
    username: 'me',
    displayName: 'Me Myself',
    avatarUrl: null,
    avatarS3Key: null,
  );

  const peerProfile = ChatProfileEntity(
    userId: peerUserId,
    username: 'ada',
    displayName: 'Ada Lovelace',
    avatarUrl: 'https://s3.example.com/a.jpg?sig=1',
    avatarS3Key: 'avatars/42/a.jpg',
  );

  ChatMemberEntity member(int userId, ChatProfileEntity? profile) =>
      ChatMemberEntity(
        userId: userId,
        roleId: 4,
        isMuted: false,
        isBanned: false,
        permissionsOverrides: const {},
        profile: profile,
      );

  MessageEntity message({required int authorId, ChatProfileEntity? profile}) =>
      MessageEntity(
        id: 'm1',
        chatId: 'c1',
        seq: 3,
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
        profile: profile,
      );

  ChatEntity chat({
    ChatType type = ChatType.direct,
    String? name,
    List<ChatMemberEntity>? members,
    MessageEntity? lastMessage,
    ChatMemberEntity? me,
  }) => ChatEntity(
    id: 'c1',
    seqCounter: 3,
    lastActivityAt: null,
    type: type,
    name: name,
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: myUserId,
    memberCount: 2,
    members: members,
    lastMessage: lastMessage,
    me: me,
  );

  group('peerProfile — from the member roster (ChatDetailDTO)', () {
    test('picks the member who is not me', () {
      final subject = chat(
        members: [member(myUserId, myProfile), member(peerUserId, peerProfile)],
      );

      expect(subject.peerProfile(myUserId), peerProfile);
      expect(subject.peerName(myUserId), 'Ada Lovelace');
    });

    test('order in the roster does not matter', () {
      final subject = chat(
        members: [member(peerUserId, peerProfile), member(myUserId, myProfile)],
      );

      expect(subject.peerProfile(myUserId), peerProfile);
    });

    test('skips a member row that carries no profile', () {
      final subject = chat(
        members: [member(myUserId, myProfile), member(peerUserId, null)],
      );

      expect(subject.peerProfile(myUserId), isNull);
    });
  });

  group('peerProfile — from last_message (ChatDTO in the list)', () {
    test('uses the author profile when the last message is not mine', () {
      final subject = chat(
        lastMessage: message(authorId: peerUserId, profile: peerProfile),
      );

      expect(subject.peerProfile(myUserId), peerProfile);
    });

    test('refuses to call MY OWN last message the peer', () {
      final subject = chat(
        lastMessage: message(authorId: myUserId, profile: myProfile),
      );

      expect(subject.peerProfile(myUserId), isNull);
    });

    test('prefers the roster over the last message when both are present', () {
      final subject = chat(
        members: [member(myUserId, myProfile), member(peerUserId, peerProfile)],
        lastMessage: message(authorId: myUserId, profile: myProfile),
      );

      expect(subject.peerProfile(myUserId), peerProfile);
    });
  });

  group('peerProfile — guards', () {
    test('is null for every non-direct chat type', () {
      for (final type in [
        ChatType.group,
        ChatType.supergroup,
        ChatType.channel,
      ]) {
        final subject = chat(
          type: type,
          members: [
            member(myUserId, myProfile),
            member(peerUserId, peerProfile),
          ],
        );
        expect(subject.peerProfile(myUserId), isNull, reason: '$type');
      }
    });

    test(
      'is null when the signed-in id is unknown and `me` cannot supply it',
      () {
        final subject = chat(
          members: [
            member(myUserId, myProfile),
            member(peerUserId, peerProfile),
          ],
        );

        // Without knowing who I am, either member could be the peer — guessing
        // would put my own name on my own chat.
        expect(subject.peerProfile(null), isNull);
      },
    );

    test('falls back to `me.userId` when the caller has no id yet', () {
      final subject = chat(
        members: [member(myUserId, myProfile), member(peerUserId, peerProfile)],
        me: member(myUserId, myProfile),
      );

      expect(subject.peerProfile(null), peerProfile);
    });
  });
}
