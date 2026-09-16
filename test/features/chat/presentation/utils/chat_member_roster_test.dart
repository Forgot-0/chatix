import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_member_roster.dart';

ChatMemberEntity member({
  required int userId,
  required ChatRole role,
  String? displayName,
  String? username,
  bool isBanned = false,
  bool isMuted = false,
}) {
  return ChatMemberEntity(
    userId: userId,
    roleId: role.id,
    isMuted: isMuted,
    isBanned: isBanned,
    permissionsOverrides: const {},
    profile: ChatProfileEntity(
      userId: userId,
      username: username,
      displayName: displayName,
      avatarUrl: null,
      avatarS3Key: null,
    ),
  );
}

ChatEntity chat({
  ChatType type = ChatType.group,
  int memberCount = 3,
  List<ChatMemberEntity>? members,
}) {
  return ChatEntity(
    id: 'c1',
    seqCounter: 0,
    lastActivityAt: null,
    type: type,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: memberCount,
    members: members,
  );
}

void main() {
  group('grouping (api-docs §8.1)', () {
    test('owner, admin and editor go above everyone else, in that order', () {
      final sections = buildMemberSections(
        members: [
          member(userId: 5, role: ChatRole.member, displayName: 'Mia'),
          member(userId: 3, role: ChatRole.editor, displayName: 'Eli'),
          member(userId: 1, role: ChatRole.owner, displayName: 'Ola'),
          member(userId: 2, role: ChatRole.admin, displayName: 'Ada'),
          member(userId: 6, role: ChatRole.viewer, displayName: 'Vic'),
        ],
      );

      expect(sections.map((s) => s.section), [
        MemberSection.administration,
        MemberSection.members,
      ]);
      expect(sections.first.members.map((m) => m.userId), [1, 2, 3]);
      expect(sections.last.members.map((m) => m.userId), [5, 6]);
    });

    test('within one role, names sort alphabetically', () {
      final sections = buildMemberSections(
        members: [
          member(userId: 9, role: ChatRole.member, displayName: 'Zoe'),
          member(userId: 8, role: ChatRole.member, displayName: 'anna'),
          member(userId: 7, role: ChatRole.member, displayName: 'Mia'),
        ],
      );

      expect(sections.single.members.map((m) => m.userId), [8, 7, 9]);
    });

    test('a user repeated across two pages is listed once', () {
      final sections = buildMemberSections(
        members: [
          member(userId: 5, role: ChatRole.member, displayName: 'Mia'),
          member(userId: 5, role: ChatRole.member, displayName: 'Mia'),
        ],
      );

      expect(sections.single.members, hasLength(1));
    });

    test('an empty roster produces no sections at all', () {
      expect(buildMemberSections(members: const []), isEmpty);
    });
  });

  group('banned members (api-docs §5.3)', () {
    test('come from the chat detail, which the paged list never carries', () {
      final banned = member(
        userId: 42,
        role: ChatRole.member,
        displayName: 'Bad Actor',
        isBanned: true,
      );

      // Exactly what the two endpoints disagree about: `GET /members/` drops
      // banned members, `ChatDetailDTO.members` keeps them.
      final sections = buildMemberSections(
        members: [member(userId: 1, role: ChatRole.owner, displayName: 'Ola')],
        banned: bannedMembersOf(
          chat(
            members: [
              banned,
              member(userId: 1, role: ChatRole.owner, displayName: 'Ola'),
            ],
          ),
        ),
      );

      expect(sections.last.section, MemberSection.banned);
      expect(sections.last.members.single.userId, 42);
    });

    test('bannedMembersOf ignores a chat with no roster attached', () {
      expect(bannedMembersOf(chat()), isEmpty);
      expect(bannedMembersOf(null), isEmpty);
    });

    test('someone in both sources is counted as banned only', () {
      final stale = member(userId: 42, role: ChatRole.member, displayName: 'B');

      final sections = buildMemberSections(
        members: [stale],
        banned: [
          member(
            userId: 42,
            role: ChatRole.member,
            displayName: 'B',
            isBanned: true,
          ),
        ],
      );

      expect(sections.map((s) => s.section), [MemberSection.banned]);
    });
  });

  group('search', () {
    final roster = [
      member(
        userId: 11,
        role: ChatRole.member,
        displayName: 'Ivan Petrov',
        username: 'ivan_dev',
      ),
      member(
        userId: 12,
        role: ChatRole.admin,
        displayName: 'Ada Lovelace',
        username: 'ada',
      ),
    ];

    test('matches part of a display name, ignoring case', () {
      final sections = buildMemberSections(members: roster, query: 'PETR');
      expect(sections.single.members.single.userId, 11);
    });

    test('matches part of a username, with or without the @', () {
      expect(
        buildMemberSections(members: roster, query: '@ivan').single.members,
        hasLength(1),
      );
      expect(
        buildMemberSections(members: roster, query: '_dev').single.members,
        hasLength(1),
      );
    });

    test('matches an exact user id', () {
      final sections = buildMemberSections(members: roster, query: '12');
      expect(sections.single.members.single.userId, 12);
    });

    test('a query nobody matches leaves no sections', () {
      expect(buildMemberSections(members: roster, query: 'zzz'), isEmpty);
    });

    test('filters the banned block too', () {
      final sections = buildMemberSections(
        members: roster,
        banned: [
          member(
            userId: 13,
            role: ChatRole.member,
            displayName: 'Ivan Banned',
            isBanned: true,
          ),
        ],
        query: 'ivan',
      );

      expect(sections.map((s) => s.section), [
        MemberSection.members,
        MemberSection.banned,
      ]);
    });

    test('an empty query keeps everyone', () {
      expect(memberMatchesQuery(roster.first, '   '), isTrue);
    });
  });

  group('member limits (api-docs §5.1)', () {
    test('each chat type has its own ceiling', () {
      expect(chatMemberCapacity(ChatType.direct), 2);
      expect(chatMemberCapacity(ChatType.group), 500);
      expect(chatMemberCapacity(ChatType.supergroup), 1000000);
      expect(chatMemberCapacity(ChatType.channel), 10000000);
    });

    test('a full direct chat has no room for anyone', () {
      expect(
        chatHasRoomForMembers(chat(type: ChatType.direct, memberCount: 2)),
        isFalse,
      );
    });

    test('room left is what the ceiling minus the count leaves', () {
      expect(remainingMemberSlots(chat(memberCount: 498)), 2);
    });

    test('a roster larger than member_count wins over the stale count', () {
      expect(remainingMemberSlots(chat(memberCount: 1), knownMembers: 500), 0);
    });

    test('an over-full chat reports zero rather than a negative number', () {
      expect(remainingMemberSlots(chat(memberCount: 900)), 0);
    });

    test('no chat means no room', () {
      expect(remainingMemberSlots(null), 0);
    });
  });
}
