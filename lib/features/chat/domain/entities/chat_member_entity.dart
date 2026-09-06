import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';

enum ChatRole {
  owner(1),
  admin(2),
  editor(3),
  direct(4),
  member(5),
  viewer(6);

  const ChatRole(this.id);

  final int id;

  static const ChatRole defaultForNewMember = ChatRole.member;

  static ChatRole? fromId(int? id) {
    if (id == null) return null;
    for (final role in ChatRole.values) {
      if (role.id == id) return role;
    }
    return null;
  }

  Map<String, bool> get permissions => ChatPermissions.matrix[this]!;
}

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

class ChatMemberEntity extends Equatable {
  final int userId;

  final int roleId;

  final bool isMuted;
  final bool isBanned;

  final Map<String, bool> permissionsOverrides;

  final ChatProfileEntity? profile;

  const ChatMemberEntity({
    required this.userId,
    required this.roleId,
    required this.isMuted,
    required this.isBanned,
    required this.permissionsOverrides,
    this.profile,
  });

  String get displayLabel => chatDisplayName(profile, userId);

  ChatRole? get role => ChatRole.fromId(roleId);

  @override
  List<Object?> get props => [
    userId,
    roleId,
    isMuted,
    isBanned,
    permissionsOverrides,
    profile,
  ];
}

class MemberPresenceEntity extends Equatable {
  final int userId;
  final bool isOnline;

  const MemberPresenceEntity({required this.userId, required this.isOnline});

  @override
  List<Object?> get props => [userId, isOnline];
}
