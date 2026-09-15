import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/data/models/chat_member_model.dart';
import 'package:chatix/features/chat/data/models/chat_profile_model.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';

part 'chat_model.g.dart';

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

/// The per-user state block: the fields of `ChatDTO` the server keeps in the
/// caller's `chat_members` row, and the whole of `ChatStateDTO` (api-docs
/// §5.2).
@JsonSerializable(fieldRename: FieldRename.snake)
class ChatStateModel extends Equatable {
  @JsonKey(defaultValue: false)
  final bool isPinned;

  final String? pinnedAt;

  @JsonKey(defaultValue: false)
  final bool isArchived;

  final String? archivedAt;

  final String? notificationsMutedUntil;

  @JsonKey(defaultValue: false)
  final bool isMutedByMe;

  final String? draft;

  final String? draftUpdatedAt;

  /// `PATCH /chats/{id}/state/` answers with the chat id; the state block
  /// inside `ChatDTO` does not repeat it.
  final String? chatId;

  const ChatStateModel({
    this.isPinned = false,
    this.pinnedAt,
    this.isArchived = false,
    this.archivedAt,
    this.notificationsMutedUntil,
    this.isMutedByMe = false,
    this.draft,
    this.draftUpdatedAt,
    this.chatId,
  });

  @override
  List<Object?> get props => [
    isPinned,
    pinnedAt,
    isArchived,
    archivedAt,
    notificationsMutedUntil,
    isMutedByMe,
    draft,
    draftUpdatedAt,
    chatId,
  ];

  factory ChatStateModel.fromJson(Map<String, dynamic> json) =>
      _$ChatStateModelFromJson(json);

  Map<String, dynamic> toJson() => _$ChatStateModelToJson(this);
}

extension ChatStateModelX on ChatStateModel {
  ChatStateEntity toEntity() {
    return ChatStateEntity(
      isPinned: isPinned,
      pinnedAt: _parseDate(pinnedAt),
      isArchived: isArchived,
      notificationsMutedUntil: _parseDate(notificationsMutedUntil),
      isMutedByMe: isMutedByMe,
      draft: draft,
    );
  }
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

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

  @JsonKey(defaultValue: 'all')
  final String reactionsMode;

  @JsonKey(defaultValue: <String>[])
  final List<String> allowedReactions;

  final int createdBy;
  final int memberCount;

  final int? unreadCount;

  final ChatMemberModel? me;

  final ReadDetailModel? lastRead;

  final MessageModel? lastMessage;

  final List<ChatMemberModel>? members;

  /// Only `GET /chats/` fills these two; `POST /chats/` and
  /// `PATCH /chats/{id}/` answer with `null` and `[]` (api-docs §5.2).
  final ChatProfileModel? peer;

  @JsonKey(defaultValue: <ChatProfileModel>[])
  final List<ChatProfileModel> membersPreview;

  @JsonKey(defaultValue: false)
  final bool isPinned;

  final String? pinnedAt;

  @JsonKey(defaultValue: false)
  final bool isArchived;

  final String? notificationsMutedUntil;

  @JsonKey(defaultValue: false)
  final bool isMutedByMe;

  final String? draft;

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
    required this.reactionsMode,
    required this.allowedReactions,
    required this.createdBy,
    required this.memberCount,
    this.unreadCount,
    this.me,
    this.lastRead,
    this.lastMessage,
    this.members,
    this.peer,
    this.membersPreview = const [],
    this.isPinned = false,
    this.pinnedAt,
    this.isArchived = false,
    this.notificationsMutedUntil,
    this.isMutedByMe = false,
    this.draft,
  });

  /// The state block as its own value.
  ///
  /// `ChatDetailDTO` carries none of these fields, so a chat fetched by id
  /// would report every flag as false. Rather than let that overwrite what
  /// the list knows, the state is dropped when the response looks like it
  /// never had one.
  ChatStateModel? get state {
    final hasState =
        isPinned ||
        isArchived ||
        isMutedByMe ||
        pinnedAt != null ||
        notificationsMutedUntil != null ||
        draft != null;
    if (!hasState) return null;

    return ChatStateModel(
      isPinned: isPinned,
      pinnedAt: pinnedAt,
      isArchived: isArchived,
      notificationsMutedUntil: notificationsMutedUntil,
      isMutedByMe: isMutedByMe,
      draft: draft,
    );
  }

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
    reactionsMode,
    allowedReactions,
    createdBy,
    memberCount,
    unreadCount,
    me,
    lastRead,
    lastMessage,
    members,
    peer,
    membersPreview,
    isPinned,
    pinnedAt,
    isArchived,
    notificationsMutedUntil,
    isMutedByMe,
    draft,
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
      reactionsMode: ChatReactionsMode.fromWire(reactionsMode),
      allowedReactions: allowedReactions,
      createdBy: createdBy,
      memberCount: memberCount,
      unreadCount: unreadCount,
      me: me?.toEntity(),
      lastRead: lastRead?.toEntity(),
      lastMessage: lastMessage?.toEntity(),
      members: members
          ?.map<ChatMemberEntity>((member) => member.toEntity())
          .toList(),
      peer: peer?.toEntity(),
      membersPreview: membersPreview
          .map<ChatProfileEntity>((profile) => profile.toEntity())
          .toList(),
      state: state?.toEntity(),
    );
  }
}

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
