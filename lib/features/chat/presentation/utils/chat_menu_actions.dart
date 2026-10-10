import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_exit_options.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';

/// What the "⋮" menu of an open chat can do.
enum ChatMenuAction {
  search,

  /// Opens the choice of how long for.
  mute,
  unmute,
  pin,
  unpin,
  archive,
  unarchive,
  selectMessages,

  /// The chat's settings — name, description, who may do what.
  manage,
  leave,
  delete;

  /// Drawn apart from the rest, in the error colour.
  bool get isDestructive =>
      this == ChatMenuAction.leave || this == ChatMenuAction.delete;
}

/// The menu for [chat], as [me] may use it, in the order it is shown.
///
/// [state] is the reader's own pin/archive/mute; `GET /chats/{id}/` does not
/// carry it (api-docs §5.2), so it comes from the list row when there is one,
/// and is read as "none of the three" when there is not.
///
/// Nothing here is offered that the server would refuse:
/// - pin, archive and mute go through `PATCH /chats/{id}/state/`, which needs
///   a membership of one's own (§5.2) and no permission beyond it;
/// - managing the chat needs `chat:update`, which the `direct` role also has
///   (§8.1) but a two-person chat has nothing to manage;
/// - leaving and deleting follow [ChatExitOptions]: a creator cannot leave
///   (§5.2), and only `chat:delete` may delete — which no `direct` member
///   has, so a direct chat is deleted for both sides only by an override.
///
/// Blocking the other person of a direct chat belongs here too, once the
/// contacts feature can do it (`POST /contacts/{user_id}/block/`, §4.13).
List<ChatMenuAction> chatMenuActionsFor(
  ChatEntity chat,
  ChatMemberEntity? me, {
  ChatStateEntity? state,
}) {
  final isMember = me != null;
  final exit = ChatExitOptions.of(chat, me);
  final mine = state ?? chat.state ?? const ChatStateEntity();

  return [
    ChatMenuAction.search,
    if (isMember) ...[
      mine.isMutedByMe ? ChatMenuAction.unmute : ChatMenuAction.mute,
      mine.isPinned ? ChatMenuAction.unpin : ChatMenuAction.pin,
      mine.isArchived ? ChatMenuAction.unarchive : ChatMenuAction.archive,
    ],
    ChatMenuAction.selectMessages,
    if (chat.type != ChatType.direct &&
        hasChatPermission(chat, me, ChatPermissions.chatUpdate))
      ChatMenuAction.manage,
    if (exit.canLeave) ChatMenuAction.leave,
    if (exit.canDelete) ChatMenuAction.delete,
  ];
}

/// Whether a call can be started from this chat's app bar.
///
/// `call:join` is in every role (§8.1), so the permission alone would put a
/// call button on a channel, whose audience is not a party to anything — a
/// channel is listened to, not called.
bool chatCallAvailable(ChatEntity chat, ChatMemberEntity? me) =>
    chat.type != ChatType.channel &&
    hasChatPermission(chat, me, ChatPermissions.callJoin);
