// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_member_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMemberModel _$ChatMemberModelFromJson(Map<String, dynamic> json) =>
    ChatMemberModel(
      userId: (json['user_id'] as num).toInt(),
      roleId: (json['role_id'] as num).toInt(),
      isMuted: json['is_muted'] as bool,
      isBanned: json['is_banned'] as bool,
      permissionsOverrides:
          (json['permissions_overrides'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          {},
    );

Map<String, dynamic> _$ChatMemberModelToJson(ChatMemberModel instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'role_id': instance.roleId,
      'is_muted': instance.isMuted,
      'is_banned': instance.isBanned,
      'permissions_overrides': instance.permissionsOverrides,
    };

MemberPresenceModel _$MemberPresenceModelFromJson(Map<String, dynamic> json) =>
    MemberPresenceModel(
      userId: (json['user_id'] as num).toInt(),
      isOnline: json['is_online'] as bool,
    );

Map<String, dynamic> _$MemberPresenceModelToJson(
  MemberPresenceModel instance,
) => <String, dynamic>{
  'user_id': instance.userId,
  'is_online': instance.isOnline,
};

ListMembersModel _$ListMembersModelFromJson(Map<String, dynamic> json) =>
    ListMembersModel(
      members:
          (json['members'] as List<dynamic>?)
              ?.map((e) => ChatMemberModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hasNext: json['has_next'] as bool,
      nextUserId: (json['next_user_id'] as num?)?.toInt(),
      presence:
          (json['presence'] as List<dynamic>?)
              ?.map(
                (e) => MemberPresenceModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );

Map<String, dynamic> _$ListMembersModelToJson(ListMembersModel instance) =>
    <String, dynamic>{
      'members': instance.members,
      'has_next': instance.hasNext,
      'next_user_id': instance.nextUserId,
      'presence': instance.presence,
    };
