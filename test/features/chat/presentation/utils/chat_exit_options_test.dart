import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_exit_options.dart';

/// The creator of a chat cannot leave it: `Chat.leave()` compares the caller
/// with `created_by` and answers 403, and nothing changes `created_by`
/// (api-docs §5.2). The screen has to know that before it draws a button.
void main() {
  const creatorId = 1;
  const memberId = 2;

  ChatEntity chat({Map<String, bool> permissions = const {}}) => ChatEntity(
    id: 'c1',
    seqCounter: 1,
    lastActivityAt: null,
    type: ChatType.group,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: permissions,
    createdBy: creatorId,
    memberCount: 3,
  );

  ChatMemberEntity member(int userId, ChatRole role) => ChatMemberEntity(
    userId: userId,
    roleId: role.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
    profile: null,
  );

  test('an ordinary member is offered the door and nothing else', () {
    final options = ChatExitOptions.of(
      chat(),
      member(memberId, ChatRole.member),
    );

    expect(options.canLeave, isTrue);
    expect(options.canDelete, isFalse);
    expect(options.notice, ChatExitNotice.none);
  });

  test('the creator is never offered a leave that would 403', () {
    final options = ChatExitOptions.of(
      chat(),
      member(creatorId, ChatRole.owner),
    );

    expect(options.canLeave, isFalse);
    expect(options.canDelete, isTrue);
    expect(options.notice, ChatExitNotice.creatorMustDelete);
  });

  test('a creator stripped of chat:delete is told they are stuck', () {
    final options = ChatExitOptions.of(
      chat(permissions: const {'chat:delete': false}),
      member(creatorId, ChatRole.owner),
    );

    expect(options.canLeave, isFalse);
    expect(options.canDelete, isFalse);
    expect(options.notice, ChatExitNotice.creatorStuck);
  });

  test('an admin who did not create the chat can both leave and delete', () {
    final options = ChatExitOptions.of(
      chat(permissions: const {'chat:delete': true}),
      member(memberId, ChatRole.admin),
    );

    expect(options.canLeave, isTrue);
    expect(options.canDelete, isTrue);
    expect(options.notice, ChatExitNotice.none);
  });

  test('without a membership there is nothing to offer', () {
    final options = ChatExitOptions.of(chat(), null);

    expect(options.canLeave, isFalse);
    expect(options.canDelete, isFalse);
    expect(options.notice, ChatExitNotice.none);
  });
}
