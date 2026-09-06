library;

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';

export 'package:chatix/features/chat/domain/entities/chat_member_entity.dart'
    show ChatPermissions;

bool hasChatPermission(
  ChatEntity? chat,
  ChatMemberEntity? me,
  String permission,
) {
  if (me == null) return false;

  if (me.isBanned) return false;

  final memberOverride = me.permissionsOverrides[permission];
  if (memberOverride != null) return memberOverride;

  final chatOverride = chat?.permissions[permission];
  if (chatOverride != null) return chatOverride;

  final role = me.role;
  if (role == null) return false;
  return role.permissions[permission] == true;
}

bool canSendMessage(ChatEntity? chat, ChatMemberEntity? me) {
  if (me == null || me.isMuted || me.isBanned) return false;

  if (chat?.adminOnly == true) {
    return hasChatPermission(chat, me, ChatPermissions.messageSendAdminOnly);
  }
  return hasChatPermission(chat, me, ChatPermissions.messageSend);
}

bool canDeleteMessage(ChatEntity? chat, ChatMemberEntity? me, int? authorId) {
  if (me == null) return false;
  if (authorId != null && authorId == me.userId) return true;
  return hasChatPermission(chat, me, ChatPermissions.messageDelete);
}

bool canEditMessage(ChatMemberEntity? me, int? authorId) {
  if (me == null || authorId == null) return false;
  if (me.isMuted || me.isBanned) return false;
  return authorId == me.userId;
}

bool canModerate(ChatMemberEntity? me, ChatMemberEntity target) {
  if (me == null) return false;
  if (me.userId == target.userId) return false;
  if (target.role == ChatRole.owner) return false;
  return true;
}

bool canLeaveChat(ChatEntity? chat, ChatMemberEntity? me) {
  if (me == null) return false;
  if (chat == null) return false;
  return chat.createdBy != me.userId;
}

bool canAssignChatRole(ChatMemberEntity? me, ChatRole role) {
  final mine = me?.role;
  if (mine == null) return false;
  return role.id > mine.id;
}

List<ChatRole> assignableChatRoles(ChatMemberEntity? me) => [
  for (final role in ChatRole.values)
    if (canAssignChatRole(me, role)) role,
];

bool hasAnyChatManagementAction(ChatEntity? chat, ChatMemberEntity? me) {
  if (me == null) return false;
  return canLeaveChat(chat, me) ||
      hasChatPermission(chat, me, ChatPermissions.chatDelete) ||
      hasChatPermission(chat, me, ChatPermissions.chatUpdate) ||
      hasChatPermission(chat, me, ChatPermissions.memberInvite);
}
