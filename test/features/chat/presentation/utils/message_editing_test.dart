import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/message_editing.dart';

void main() {
  const myId = 7;

  ChatMemberEntity me({bool muted = false}) => ChatMemberEntity(
    userId: myId,
    roleId: ChatRole.member.id,
    isMuted: muted,
    isBanned: false,
    permissionsOverrides: const {},
  );

  MessageEntity message(
    String id, {
    int authorId = myId,
    MessageType type = MessageType.text,
    String? content = 'text',
  }) => MessageEntity(
    id: id,
    chatId: 'c',
    seq: 1,
    authorId: authorId,
    type: type,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  test('is the newest message of mine', () {
    final picked = lastEditableMessage([
      message('theirs', authorId: 42),
      message('mine-new'),
      message('mine-old'),
    ], me());

    expect(picked?.id, 'mine-new');
  });

  test('steps over what has no words to edit', () {
    final picked = lastEditableMessage([
      message('voice', type: MessageType.voice, content: null),
      message('note', type: MessageType.videoNote, content: null),
      message('system', type: MessageType.system),
      message('photo', type: MessageType.image, content: null),
    ], me());

    // A photo without a caption is fair game: editing it adds one.
    expect(picked?.id, 'photo');
  });

  test('is nothing for a reader who may not edit', () {
    expect(lastEditableMessage([message('mine')], me(muted: true)), isNull);
    expect(lastEditableMessage([message('mine')], null), isNull);
  });

  test('is nothing when the window holds nothing of mine', () {
    expect(lastEditableMessage([message('x', authorId: 42)], me()), isNull);
  });
}
