// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadDetailModel _$ReadDetailModelFromJson(Map<String, dynamic> json) =>
    ReadDetailModel(
      lastReadMessageSeq: (json['last_read_message_seq'] as num).toInt(),
      lastReadAt: json['last_read_at'] as String?,
    );

Map<String, dynamic> _$ReadDetailModelToJson(ReadDetailModel instance) =>
    <String, dynamic>{
      'last_read_message_seq': instance.lastReadMessageSeq,
      'last_read_at': instance.lastReadAt,
    };

ChatStateModel _$ChatStateModelFromJson(Map<String, dynamic> json) =>
    ChatStateModel(
      isPinned: json['is_pinned'] as bool? ?? false,
      pinnedAt: json['pinned_at'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      archivedAt: json['archived_at'] as String?,
      notificationsMutedUntil: json['notifications_muted_until'] as String?,
      isMutedByMe: json['is_muted_by_me'] as bool? ?? false,
      draft: json['draft'] as String?,
      draftUpdatedAt: json['draft_updated_at'] as String?,
      chatId: json['chat_id'] as String?,
    );

Map<String, dynamic> _$ChatStateModelToJson(ChatStateModel instance) =>
    <String, dynamic>{
      'is_pinned': instance.isPinned,
      'pinned_at': instance.pinnedAt,
      'is_archived': instance.isArchived,
      'archived_at': instance.archivedAt,
      'notifications_muted_until': instance.notificationsMutedUntil,
      'is_muted_by_me': instance.isMutedByMe,
      'draft': instance.draft,
      'draft_updated_at': instance.draftUpdatedAt,
      'chat_id': instance.chatId,
    };

ChatModel _$ChatModelFromJson(Map<String, dynamic> json) => ChatModel(
  id: json['id'] as String,
  seqCounter: (json['seq_counter'] as num).toInt(),
  lastActivityAt: json['last_activity_at'] as String?,
  type: json['type'] as String,
  name: json['name'] as String?,
  description: json['description'] as String?,
  avatarS3Key: json['avatar_s3_key'] as String?,
  isPublic: json['is_public'] as bool,
  adminOnly: json['admin_only'] as bool,
  slowModeSeconds: (json['slow_mode_seconds'] as num).toInt(),
  permissions:
      (json['permissions'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as bool),
      ) ??
      {},
  reactionsMode: json['reactions_mode'] as String? ?? 'all',
  allowedReactions:
      (json['allowed_reactions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  createdBy: (json['created_by'] as num).toInt(),
  memberCount: (json['member_count'] as num).toInt(),
  unreadCount: (json['unread_count'] as num?)?.toInt(),
  me: json['me'] == null
      ? null
      : ChatMemberModel.fromJson(json['me'] as Map<String, dynamic>),
  lastRead: json['last_read'] == null
      ? null
      : ReadDetailModel.fromJson(json['last_read'] as Map<String, dynamic>),
  lastMessage: json['last_message'] == null
      ? null
      : MessageModel.fromJson(json['last_message'] as Map<String, dynamic>),
  members: (json['members'] as List<dynamic>?)
      ?.map((e) => ChatMemberModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  peer: json['peer'] == null
      ? null
      : ChatProfileModel.fromJson(json['peer'] as Map<String, dynamic>),
  membersPreview:
      (json['members_preview'] as List<dynamic>?)
          ?.map((e) => ChatProfileModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  isPinned: json['is_pinned'] as bool? ?? false,
  pinnedAt: json['pinned_at'] as String?,
  isArchived: json['is_archived'] as bool? ?? false,
  notificationsMutedUntil: json['notifications_muted_until'] as String?,
  isMutedByMe: json['is_muted_by_me'] as bool? ?? false,
  draft: json['draft'] as String?,
);

Map<String, dynamic> _$ChatModelToJson(ChatModel instance) => <String, dynamic>{
  'id': instance.id,
  'seq_counter': instance.seqCounter,
  'last_activity_at': instance.lastActivityAt,
  'type': instance.type,
  'name': instance.name,
  'description': instance.description,
  'avatar_s3_key': instance.avatarS3Key,
  'is_public': instance.isPublic,
  'admin_only': instance.adminOnly,
  'slow_mode_seconds': instance.slowModeSeconds,
  'permissions': instance.permissions,
  'reactions_mode': instance.reactionsMode,
  'allowed_reactions': instance.allowedReactions,
  'created_by': instance.createdBy,
  'member_count': instance.memberCount,
  'unread_count': instance.unreadCount,
  'me': instance.me,
  'last_read': instance.lastRead,
  'last_message': instance.lastMessage,
  'members': instance.members,
  'peer': instance.peer,
  'members_preview': instance.membersPreview,
  'is_pinned': instance.isPinned,
  'pinned_at': instance.pinnedAt,
  'is_archived': instance.isArchived,
  'notifications_muted_until': instance.notificationsMutedUntil,
  'is_muted_by_me': instance.isMutedByMe,
  'draft': instance.draft,
};

ListChatsModel _$ListChatsModelFromJson(Map<String, dynamic> json) =>
    ListChatsModel(
      hasNext: json['has_next'] as bool,
      chats:
          (json['chats'] as List<dynamic>?)
              ?.map((e) => ChatModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nextDate: json['next_date'] as String?,
      nextChatId: json['next_chat_id'] as String?,
    );

Map<String, dynamic> _$ListChatsModelToJson(ListChatsModel instance) =>
    <String, dynamic>{
      'has_next': instance.hasNext,
      'chats': instance.chats,
      'next_date': instance.nextDate,
      'next_chat_id': instance.nextChatId,
    };
