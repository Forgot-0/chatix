import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';

/// Whether [me] is granted [permission] in [chat], for deciding which
/// management controls to render.
///
/// ### Resolution order (api-docs §9.1)
///
/// The effective right is the **union of three layers**, most specific
/// winning:
///
/// ```
///   1. role baseline        ChatRole.permissions       (the §9.1 matrix)
///   2. chat-level override  chat.permissions           (CreateChat/UpdateChat)
///   3. member override      me.permissionsOverrides    (per-person)
/// ```
///
/// An override can flip a permission in *either* direction — layer 3 may grant
/// something the role denies **and** revoke something the role grants — so
/// each layer is checked for key *presence*, not truthiness. Short-circuiting
/// on "role already says true" would ignore a revoking override and show a
/// button the server then rejects.
///
/// ### This is UX, not security
///
/// The backend's `ChatAccessService` performs the authoritative merge and
/// still enforces every check; hiding a control here only spares the user a
/// guaranteed `403`. It also runs on *the last data we received*: a role or
/// override changed elsewhere a second ago isn't reflected until the next
/// `getChat`/`getMembers` — so a hidden button is never a guarantee, and a
/// visible one is never a promise.
///
/// [me] is nullable on purpose: a non-member previewing a public chat has no
/// membership, and every permission must then read as denied (fail-closed).
bool hasChatPermission(
  ChatEntity? chat,
  ChatMemberEntity? me,
  String permission,
) {
  if (me == null) return false;

  // A banned member keeps their role on paper but can do nothing — check this
  // before the layers, since none of them encode ban state.
  if (me.isBanned) return false;

  // Layer 3 — personal override, most specific.
  final memberOverride = me.permissionsOverrides[permission];
  if (memberOverride != null) return memberOverride;

  // Layer 2 — chat-wide override.
  final chatOverride = chat?.permissions[permission];
  if (chatOverride != null) return chatOverride;

  // Layer 1 — role baseline. An unknown `role_id` (not in our copy of the
  // §9.1 matrix) yields no role, hence no permission.
  final role = me.role;
  if (role == null) return false;
  return role.permissions[permission] == true;
}

/// Whether [me] may post in [chat] right now.
///
/// More than one permission is involved, which is why this is its own helper:
/// a chat with `admin_only == true` requires
/// [ChatPermissions.messageSendAdminOnly] *instead of* the ordinary
/// [ChatPermissions.messageSend] (api-docs §6.2, §9.1) — so a plain `member`
/// holding `message:send` still cannot write in an admin-only chat. A muted
/// member is likewise blocked regardless of permissions.
bool canSendMessage(ChatEntity? chat, ChatMemberEntity? me) {
  if (me == null || me.isMuted || me.isBanned) return false;

  if (chat?.adminOnly == true) {
    return hasChatPermission(chat, me, ChatPermissions.messageSendAdminOnly);
  }
  return hasChatPermission(chat, me, ChatPermissions.messageSend);
}

/// Whether [me] may delete [authorId]'s message.
///
/// Authors may always remove their own message; removing somebody else's
/// needs [ChatPermissions.messageDelete] (api-docs §9.1).
bool canDeleteMessage(
  ChatEntity? chat,
  ChatMemberEntity? me,
  int? authorId,
) {
  if (me == null) return false;
  if (authorId != null && authorId == me.userId) return true;
  return hasChatPermission(chat, me, ChatPermissions.messageDelete);
}

/// Whether [me] may edit a message — only ever the author's own, and only
/// while not muted or banned. There is no "edit anyone's message" permission
/// in §9.1, so no override can grant it.
bool canEditMessage(ChatMemberEntity? me, int? authorId) {
  if (me == null || authorId == null) return false;
  if (me.isMuted || me.isBanned) return false;
  return authorId == me.userId;
}

/// Whether a moderation action may target [target].
///
/// Independent of any permission: nobody kicks/bans/demotes **themselves**
/// (leaving is the `leave` endpoint), and the chat's **owner** is untouchable
/// — an admin holds `member:kick` and `role:change` but must not be able to
/// remove or demote the owner. Combine with the relevant
/// [hasChatPermission] check:
///
/// ```dart
/// if (hasChatPermission(chat, me, ChatPermissions.memberKick) &&
///     canModerate(me, target)) { ...show the Kick button... }
/// ```
bool canModerate(ChatMemberEntity? me, ChatMemberEntity target) {
  if (me == null) return false;
  if (me.userId == target.userId) return false;
  if (target.role == ChatRole.owner) return false;
  return true;
}
