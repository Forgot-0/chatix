import 'package:equatable/equatable.dart';

/// Chat member roles (`ChatRolesEnum`, api-docs §9.1). The numeric ids are
/// backend seed data, so they are pinned explicitly rather than relying on
/// declaration order.
///
/// ⚠️ [direct] (id=4) is **not** a "lesser member" — it is the role both
/// participants of a 1:1 chat get, and it can `chat:update` (which [member]
/// cannot) while it cannot `message:delete` (which [editor] can). Ordering
/// these roles by "power" is therefore meaningless; always resolve concrete
/// permissions through [ChatRole.permissions] / `hasChatPermission`.
enum ChatRole {
  owner(1),
  admin(2),
  editor(3),
  direct(4),
  member(5),
  viewer(6);

  const ChatRole(this.id);

  final int id;

  /// Default `role_id` the backend assigns to invitees of group/supergroup
  /// chats and the default of `AddMemberRequest.role_id` (api-docs §9.1).
  static const ChatRole defaultForNewMember = ChatRole.member;

  static ChatRole? fromId(int? id) {
    if (id == null) return null;
    for (final role in ChatRole.values) {
      if (role.id == id) return role;
    }
    // Unknown ids (a role added to the backend seed after this build) are
    // reported as null so callers fail closed instead of guessing a role.
    return null;
  }

  /// The role's own row of the api-docs §9.1 matrix. This is only the
  /// *baseline*; chat-level and member-level overrides are layered on top of
  /// it by `hasChatPermission`.
  Map<String, bool> get permissions => ChatPermissions.matrix[this]!;
}

/// Canonical chat-permission keys (api-docs §9.1). Use these constants
/// instead of hand-typing the strings — one typo in a literal silently
/// hides a button forever, and the compiler cannot catch it.
abstract final class ChatPermissions {
  static const String chatDelete = 'chat:delete';
  static const String chatUpdate = 'chat:update';
  static const String chatGet = 'chat:get';

  static const String memberInvite = 'member:invite';
  static const String memberKick = 'member:kick';
  static const String memberBan = 'member:ban';
  static const String memberMute = 'member:mute';

  static const String roleChange = 'role:change';
  static const String permissionUpdate = 'permission:update';

  static const String messageRead = 'message:read';
  static const String messageSend = 'message:send';
  static const String messageDelete = 'message:delete';
  static const String messagePin = 'message:pin';
  static const String messageSendAdminOnly = 'message:send_admin_only';

  static const String settingsUpdate = 'settings:update';
  static const String settingsGet = 'settings:get';

  static const String channelPublish = 'channel:publish';
  static const String channelEdit = 'channel:edit';
  static const String channelManageSubscribers = 'channel:manage_subscribers';

  static const String slowmodeBypass = 'slowmode:bypass';

  static const String callJoin = 'call:join';
  static const String callMuteMember = 'call:mute_member';
  static const String callEnd = 'call:end';

  /// The full api-docs §9.1 matrix, transcribed row by row.
  ///
  /// Every role maps every key explicitly (no implicit `false` by omission)
  /// so that a *present* key always means "the role default says this", and
  /// an absent key means "this permission doesn't exist in our copy of the
  /// matrix" — a distinction `hasChatPermission` relies on.
  static const Map<ChatRole, Map<String, bool>> matrix = {
    ChatRole.owner: {
      chatDelete: true,
      chatUpdate: true,
      chatGet: true,
      memberInvite: true,
      memberKick: true,
      memberBan: true,
      memberMute: true,
      roleChange: true,
      permissionUpdate: true,
      messageRead: true,
      messageSend: true,
      messageDelete: true,
      messagePin: true,
      messageSendAdminOnly: true,
      settingsUpdate: true,
      settingsGet: true,
      channelPublish: true,
      channelEdit: true,
      channelManageSubscribers: true,
      slowmodeBypass: true,
      callJoin: true,
      callMuteMember: true,
      callEnd: true,
    },
    ChatRole.admin: {
      chatDelete: false,
      chatUpdate: true,
      chatGet: true,
      memberInvite: true,
      memberKick: true,
      memberBan: true,
      memberMute: true,
      roleChange: true,
      permissionUpdate: true,
      messageRead: true,
      messageSend: true,
      messageDelete: true,
      messagePin: true,
      messageSendAdminOnly: true,
      settingsUpdate: true,
      settingsGet: true,
      channelPublish: true,
      channelEdit: true,
      channelManageSubscribers: true,
      slowmodeBypass: true,
      callJoin: true,
      callMuteMember: true,
      callEnd: true,
    },
    ChatRole.editor: {
      chatDelete: false,
      chatUpdate: false,
      chatGet: true,
      memberInvite: false,
      memberKick: false,
      memberBan: false,
      memberMute: false,
      roleChange: false,
      permissionUpdate: false,
      messageRead: true,
      messageSend: true,
      messageDelete: true,
      messagePin: true,
      messageSendAdminOnly: true,
      settingsUpdate: false,
      settingsGet: true,
      channelPublish: true,
      channelEdit: true,
      channelManageSubscribers: false,
      slowmodeBypass: true,
      callJoin: true,
      callMuteMember: false,
      callEnd: false,
    },
    // ⚠️ `direct` can chat:update and message:pin but NOT message:delete —
    // see the enum doc; this row is not "member + extras".
    ChatRole.direct: {
      chatDelete: false,
      chatUpdate: true,
      chatGet: true,
      memberInvite: false,
      memberKick: false,
      memberBan: false,
      memberMute: false,
      roleChange: false,
      permissionUpdate: false,
      messageRead: true,
      messageSend: true,
      messageDelete: false,
      messagePin: true,
      messageSendAdminOnly: false,
      settingsUpdate: false,
      settingsGet: true,
      channelPublish: false,
      channelEdit: false,
      channelManageSubscribers: false,
      slowmodeBypass: false,
      callJoin: true,
      callMuteMember: false,
      callEnd: false,
    },
    ChatRole.member: {
      chatDelete: false,
      chatUpdate: false,
      chatGet: true,
      memberInvite: false,
      memberKick: false,
      memberBan: false,
      memberMute: false,
      roleChange: false,
      permissionUpdate: false,
      messageRead: true,
      messageSend: true,
      messageDelete: false,
      messagePin: false,
      messageSendAdminOnly: false,
      settingsUpdate: false,
      settingsGet: true,
      channelPublish: false,
      channelEdit: false,
      channelManageSubscribers: false,
      slowmodeBypass: false,
      callJoin: true,
      callMuteMember: false,
      callEnd: false,
    },
    // viewer = channel subscriber: reads everything, sends nothing.
    ChatRole.viewer: {
      chatDelete: false,
      chatUpdate: false,
      chatGet: true,
      memberInvite: false,
      memberKick: false,
      memberBan: false,
      memberMute: false,
      roleChange: false,
      permissionUpdate: false,
      messageRead: true,
      messageSend: false,
      messageDelete: false,
      messagePin: false,
      messageSendAdminOnly: false,
      settingsUpdate: false,
      settingsGet: true,
      channelPublish: false,
      channelEdit: false,
      channelManageSubscribers: false,
      slowmodeBypass: false,
      callJoin: true,
      callMuteMember: false,
      callEnd: false,
    },
  };
}

/// `MemberChatDTO` (api-docs §6.2/§6.3) — exactly five fields; the DTO
/// carries no username/avatar, so member screens must resolve display data
/// from the profiles module by [userId].
class ChatMemberEntity extends Equatable {
  final int userId;

  /// Raw `role_id` as sent by the backend, kept alongside [role] so an id
  /// that isn't in our copy of §9.1 still round-trips instead of being
  /// silently coerced to `member`.
  final int roleId;

  final bool isMuted;
  final bool isBanned;

  /// Per-member permission override map, layered over the role baseline and
  /// the chat-level overrides (api-docs §9.1).
  final Map<String, bool> permissionsOverrides;

  const ChatMemberEntity({
    required this.userId,
    required this.roleId,
    required this.isMuted,
    required this.isBanned,
    required this.permissionsOverrides,
  });

  /// `null` when [roleId] isn't one of the six documented roles.
  ChatRole? get role => ChatRole.fromId(roleId);

  @override
  List<Object?> get props => [
    userId,
    roleId,
    isMuted,
    isBanned,
    permissionsOverrides,
  ];
}

/// `MemberPresenceDTO` (api-docs §6.3) — only populated when the members
/// request passes `include_presence=true`.
class MemberPresenceEntity extends Equatable {
  final int userId;
  final bool isOnline;

  const MemberPresenceEntity({required this.userId, required this.isOnline});

  @override
  List<Object?> get props => [userId, isOnline];
}
