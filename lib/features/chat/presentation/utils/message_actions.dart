import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';

/// Everything the context menu can offer on one message.
enum MessageAction { reply, react, copy, forward, edit, select, delete, details }

/// Which of those this reader may actually do, here, to this message.
///
/// Rights come from [chat_permissions] rather than from reading roles: the
/// server resolves a member override, then a chat override, then the role
/// matrix (api-docs §8.1), and re-deriving that per menu item is how two
/// screens end up disagreeing about who can delete.
///
/// Pinning is deliberately absent. The role matrix carries a `message:pin`
/// right, but no endpoint in api-docs pins anything, so there is nothing the
/// menu item could call.
abstract final class MessageActions {
  static List<MessageAction> of({
    required ChatEntity? chat,
    required ChatMemberEntity? me,
    required MessageEntity message,
    required bool canReact,
    required bool canSelect,
  }) {
    // A system message is the server talking about the conversation. There is
    // no author to reply to and nothing to edit.
    if (message.type == MessageType.system) {
      return const [MessageAction.copy, MessageAction.details];
    }

    final hasText = message.content?.trim().isNotEmpty ?? false;

    return [
      if (canSendMessage(chat, me)) MessageAction.reply,
      if (canReact) MessageAction.react,
      if (hasText) MessageAction.copy,
      MessageAction.forward,
      if (canEditMessage(me, message.authorId)) MessageAction.edit,
      if (canSelect) MessageAction.select,
      if (canDeleteMessage(chat, me, message.authorId)) MessageAction.delete,
      MessageAction.details,
    ];
  }
}
