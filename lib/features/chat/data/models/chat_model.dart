import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/data/models/chat_member_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';

part 'chat_model.g.dart';

/// `ReadDetail`, embedded as `ChatDTO.last_read` (api-docs §6.2).
@JsonSerializable(fieldRename: FieldRename.snake)
class ReadDetailModel extends Equatable {
  final int lastReadMessageSeq;
  final String? lastReadAt;

  const ReadDetailModel({
    required this.lastReadMessageSeq,
    required this.lastReadAt,
  });

  @override
  List<Object?> get props => [lastReadMessageSeq, lastReadAt];

  factory ReadDetailModel.fromJson(Map<String, dynamic> json) =>
      _$ReadDetailModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReadDetailModelToJson(this);
}

extension ReadDetailModelX on ReadDetailModel {
  ReadDetailEntity toEntity() {
    return ReadDetailEntity(
      lastReadMessageSeq: lastReadMessageSeq,
      lastReadAt: lastReadAt == null ? null : DateTime.parse(lastReadAt!),
    );
  }
}

/// `ChatDTO` **and** `ChatDetaiDTO` (api-docs §6.2) in one model.
///
/// The two DTOs are supersets of a common core; the four fields that differ
/// ([unreadCount], [me], [lastRead], [members]) are all nullable here, so the
/// same class parses either response and `null` faithfully means "this
/// endpoint doesn't send it" — see [ChatEntity]'s table. Splitting them into
/// two models would duplicate 12 identical fields and force two parse paths
/// for what the backend treats as one resource.
///
/// [type] and the datetime fields stay as wire strings, converted in
/// [toEntity].
@JsonSerializable(fieldRename: FieldRename.snake)
class ChatModel extends Equatable {
  final String id;
  final int seqCounter;
  final String? lastActivityAt;
  final String type;
  final String? name;
  final String? description;
  final String? avatarS3Key;
  final bool isPublic;
  final bool adminOnly;
  final int slowModeSeconds;

  @JsonKey(defaultValue: <String, bool>{})
  final Map<String, bool> permissions;

  final int createdBy;
  final int memberCount;

  /// `ChatDTO` only.
  final int? unreadCount;

  /// `ChatDTO` only.
  final ChatMemberModel? me;

  /// `ChatDTO` only.
  final ReadDetailModel? lastRead;

  /// `ChatDetaiDTO` only. Left `null` (not `[]`) when absent so the entity can
  /// distinguish "not sent" from "no members".
  final List<ChatMemberModel>? members;

  const ChatModel({
    required this.id,
    required this.seqCounter,
    required this.lastActivityAt,
    required this.type,
    required this.name,
    required this.description,
    required this.avatarS3Key,
    required this.isPublic,
    required this.adminOnly,
    required this.slowModeSeconds,
    required this.permissions,
    required this.createdBy,
    required this.memberCount,
    this.unreadCount,
    this.me,
    this.lastRead,
    this.members,
  });

  @override
  List<Object?> get props => [
    id,
    seqCounter,
    lastActivityAt,
    type,
    name,
    description,
    avatarS3Key,
    isPublic,
    adminOnly,
    slowModeSeconds,
    permissions,
    createdBy,
    memberCount,
    unreadCount,
    me,
    lastRead,
    members,
  ];

  factory ChatModel.fromJson(Map<String, dynamic> json) =>
      _$ChatModelFromJson(json);

  Map<String, dynamic> toJson() => _$ChatModelToJson(this);
}

extension ChatModelX on ChatModel {
  ChatEntity toEntity() {
    return ChatEntity(
      id: id,
      seqCounter: seqCounter,
      lastActivityAt: lastActivityAt == null
          ? null
          : DateTime.parse(lastActivityAt!),
      type: ChatType.fromWire(type),
      name: name,
      description: description,
      avatarS3Key: avatarS3Key,
      isPublic: isPublic,
      adminOnly: adminOnly,
      slowModeSeconds: slowModeSeconds,
      permissions: permissions,
      createdBy: createdBy,
      memberCount: memberCount,
      unreadCount: unreadCount,
      me: me?.toEntity(),
      lastRead: lastRead?.toEntity(),
      members: members
          ?.map<ChatMemberEntity>((member) => member.toEntity())
          .toList(),
    );
  }
}

/// `ListChats` (api-docs §6.2) — cursor-paginated chat page.
///
/// [nextDate] deliberately stays a `String?`: it is an opaque cursor echoed
/// straight back as `last_activity_at`, so it must not be round-tripped
/// through `DateTime` (see [ChatsPage]).
@JsonSerializable(fieldRename: FieldRename.snake)
class ListChatsModel extends Equatable {
  final bool hasNext;

  @JsonKey(defaultValue: <ChatModel>[])
  final List<ChatModel> chats;

  final String? nextDate;
  final String? nextChatId;

  const ListChatsModel({
    required this.hasNext,
    required this.chats,
    required this.nextDate,
    required this.nextChatId,
  });

  @override
  List<Object?> get props => [hasNext, chats, nextDate, nextChatId];

  factory ListChatsModel.fromJson(Map<String, dynamic> json) =>
      _$ListChatsModelFromJson(json);

  Map<String, dynamic> toJson() => _$ListChatsModelToJson(this);
}
