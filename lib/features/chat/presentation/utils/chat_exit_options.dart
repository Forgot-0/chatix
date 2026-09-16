import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';

/// Why the way out of a chat is not the usual one.
enum ChatExitNotice {
  /// Nothing to explain: leaving works.
  none,

  /// The reader created this chat, so `/leave/` is closed to them, but they
  /// can still delete it.
  creatorMustDelete,

  /// The reader created this chat and has since lost `chat:delete`. There is
  /// no way out at all, which is a thing to say plainly rather than to find
  /// out from a 403.
  creatorStuck,
}

/// Which of "leave" and "delete" to offer, and what to say instead.
///
/// ⚠️ `Chat.leave()` compares the caller with the chat's `created_by` — not
/// with their role — and answers `403 CHAT_ACCESS_DENIED` when they match.
/// No endpoint changes `created_by`, and a role change does not help
/// (api-docs §5.2). So a creator is never shown a Leave button that is
/// guaranteed to fail; they are told why, and offered the only exit there
/// is.
class ChatExitOptions extends Equatable {
  const ChatExitOptions({
    required this.canLeave,
    required this.canDelete,
    required this.notice,
  });

  final bool canLeave;
  final bool canDelete;
  final ChatExitNotice notice;

  static ChatExitOptions of(ChatEntity chat, ChatMemberEntity? me) {
    if (me == null) {
      // Not a member as far as this screen knows — no membership, no exit.
      return const ChatExitOptions(
        canLeave: false,
        canDelete: false,
        notice: ChatExitNotice.none,
      );
    }

    final isCreator = chat.createdBy == me.userId;
    final canDelete = hasChatPermission(chat, me, ChatPermissions.chatDelete);

    return ChatExitOptions(
      canLeave: canLeaveChat(chat, me),
      canDelete: canDelete,
      notice: !isCreator
          ? ChatExitNotice.none
          : canDelete
          ? ChatExitNotice.creatorMustDelete
          : ChatExitNotice.creatorStuck,
    );
  }

  @override
  List<Object?> get props => [canLeave, canDelete, notice];
}
