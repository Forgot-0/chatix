library;
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';

/// **The** place the UI asks "may this person do that?".
///
/// ### Why this lives in `core/` and not in each feature
///
/// The two permission models (chat §9.1, project §9.2) were written inside
/// the features that first needed them, which was fine while each was only
/// read by its own screens. It stopped being fine the moment the same
/// question had to be answered from somewhere that belongs to neither
/// feature — an app-bar action, an overflow menu, a shell-level guard — and
/// from screens of the *other* feature (a project page offering "open the
/// team chat", a chat page linking back to its project).
///
/// Two independent copies of a permission rule drift. When they do, the
/// symptom is not a crash but a button that appears for someone who then
/// gets a 403, which is exactly the experience api-docs §10.6 asks us to
/// avoid. So the rules live here once, and the feature-level
/// `chat_permissions.dart` / `project_permissions.dart` files are now
/// re-export shims — existing imports keep working, but there is only one
/// implementation to fix.
///
/// ### Three systems, deliberately not unified
///
/// api-docs §9 opens by warning that chat roles, project roles and system
/// (auth) roles are three unrelated tables whose numeric ids collide. This
/// file keeps them in three separate namespaces for that reason: there is no
/// generic `hasPermission(subject, permission)` and there should not be —
/// `role_id == 2` means "chat admin" in one and "project maintainer" in the
/// other, and any API that lets those be passed interchangeably is a bug
/// waiting to be typed.
///
/// ### This is UX, not security
///
/// The backend (`ChatAccessService` / the project permission service)
/// performs the authoritative check on every request and is the only thing
/// standing between a user and an action. Everything here decides what to
/// *draw*, from the last data we received — a role changed a second ago
/// isn't reflected until the next fetch. A hidden control is therefore never
/// a guarantee, and a visible one is never a promise: every action must
/// still surface the server's error if it comes back 403.


export 'package:chatix/features/chat/domain/entities/chat_member_entity.dart'
    show ChatPermissions;

// ---------------------------------------------------------------------------
// Chat — api-docs §9.1
// ---------------------------------------------------------------------------

/// Whether [me] is granted [permission] in [chat].
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

/// Whether [me] may walk away from [chat] on their own.
///
/// The owner is excluded: `POST /chats/{id}/leave/` would leave the chat
/// ownerless, and api-docs §6.3 offers no ownership transfer — the owner's
/// exit is `chat:delete`, which is a different (and much louder) action.
/// Used to decide whether the chat app-bar shows "Leave" or "Delete".
bool canLeaveChat(ChatEntity? chat, ChatMemberEntity? me) {
  if (me == null) return false;
  return me.role != ChatRole.owner;
}

// ---------------------------------------------------------------------------
// Project — api-docs §9.2
// ---------------------------------------------------------------------------

/// Canonical project-permission keys (api-docs §9.2). Use these constants
/// everywhere instead of hand-typing the strings — one typo in a literal
/// silently disables a button.
///
/// ⚠️ [memberUpdate] maps to the string `"member:udpate"` — the misspelling
/// (`udpate`, no second "a") is baked into the backend seed data and must be
/// sent/compared verbatim, even though our Dart symbol is spelled correctly.
abstract final class ProjectPermissions {
  static const String memberRead = 'member:read';
  static const String memberInvite = 'member:invite';
  static const String memberKick = 'member:kick';

  /// ⚠️ Intentional backend typo — see class doc.
  static const String memberUpdate = 'member:udpate';

  static const String projectRead = 'project:read';
  static const String projectUpdate = 'project:update';
  static const String projectVisibility = 'project:visibility';
  static const String projectDelete = 'project:delete';

  static const String positionCreate = 'position:create';
  static const String positionUpdate = 'position:update';
  static const String positionDelete = 'position:delete';

  static const String permissionUpdate = 'permission:update';
}

/// Whether the current member ([me]) is granted [permission] on the project.
///
/// Resolution order (api-docs §5.2, §10.6):
///   1. `me.permissionsOverrides[permission]` if that key is present — a
///      per-member override wins over the role default (either direction).
///   2. otherwise `me.role.permissions[permission] == true`.
///   3. otherwise `false` (fail-closed).
///
/// Note the asymmetry with [hasChatPermission]: a project has **two** layers,
/// not three. There is no project-wide override dictionary in the API —
/// `ProjectDTO` carries no `permissions` field — so anything that isn't a
/// per-member override falls straight through to the role matrix.
///
/// [me] is nullable on purpose: for a viewer who isn't a member of the
/// project (e.g. browsing a public project) there's no membership, so every
/// management permission is denied and the corresponding buttons stay hidden.
bool hasProjectPermission(ProjectMemberEntity? me, String permission) {
  if (me == null) return false;

  final override = me.permissionsOverrides[permission];
  if (override != null) return override;

  final role = me.role;
  if (role == null) return false;
  return role.permissions[permission] == true;
}

/// Whether [me] has *any* project-management right worth opening a menu for.
///
/// Lets an app bar decide between "render an overflow button" and "render
/// nothing at all" without repeating the four individual checks — an empty
/// `PopupMenuButton` is a small but real usability bug (it opens onto
/// nothing), and api-docs §10.6 asks for the menu itself to disappear rather
/// than show a list of things the user may not do.
bool hasAnyProjectManagementPermission(ProjectMemberEntity? me) {
  if (me == null) return false;
  return hasProjectPermission(me, ProjectPermissions.memberInvite) ||
      hasProjectPermission(me, ProjectPermissions.memberUpdate) ||
      hasProjectPermission(me, ProjectPermissions.projectUpdate) ||
      hasProjectPermission(me, ProjectPermissions.positionCreate) ||
      hasProjectPermission(me, ProjectPermissions.projectDelete);
}

/// The chat counterpart of [hasAnyProjectManagementPermission] — whether the
/// chat app bar's overflow menu would contain anything at all.
///
/// "Leave" counts: it is available to every non-owner member regardless of
/// permissions, and it is the one entry that keeps the menu non-empty for an
/// ordinary participant.
bool hasAnyChatManagementAction(ChatEntity? chat, ChatMemberEntity? me) {
  if (me == null) return false;
  return canLeaveChat(chat, me) ||
      hasChatPermission(chat, me, ChatPermissions.chatDelete) ||
      hasChatPermission(chat, me, ChatPermissions.chatUpdate) ||
      hasChatPermission(chat, me, ChatPermissions.memberInvite);
}
