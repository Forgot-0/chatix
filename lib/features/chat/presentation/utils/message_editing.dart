import 'package:chatix/core/rbac/permission_helpers.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// The message ↑ in an empty composer opens for editing: the newest one the
/// reader wrote that an edit can change.
///
/// [newestFirst] is the feed's window as the provider keeps it. A voice
/// message and a video note have no words to edit and are stepped over, as
/// are the server's own notes; a photo without a caption is not — editing
/// it is how a caption gets added. Null when there is nothing of the
/// reader's in the window, or they may not edit at all (muted, banned).
MessageEntity? lastEditableMessage(
  Iterable<MessageEntity> newestFirst,
  ChatMemberEntity? me,
) {
  for (final message in newestFirst) {
    switch (message.type) {
      case MessageType.system:
      case MessageType.voice:
      case MessageType.videoNote:
        continue;
      case MessageType.text:
      case MessageType.image:
      case MessageType.file:
      case MessageType.reply:
      case MessageType.forward:
        if (canEditMessage(me, message.authorId)) return message;
    }
  }
  return null;
}
