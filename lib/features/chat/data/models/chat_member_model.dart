import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';

part 'chat_member_model.g.dart';

/// `MemberChatDTO` (api-docs §6.2, §6.3).
///
/// [permissionsOverrides] is defaulted to `{}` rather than being required:
/// the field is always present in the documented schema, but a member with no
/// overrides is by far the common case and an absent key must degrade to
/// "no overrides" (fall back to the role matrix) instead of throwing.
@JsonSerializable(fieldRename: FieldRename.snake)
class ChatMemberModel extends Equatable {
  final int userId;
  final int roleId;
  final bool isMuted;
  final bool isBanned;
  @JsonKey(defaultValue: <String, bool>{})
  final Map<String, bool> permissionsOverrides;

  const ChatMemberModel({
    required this.userId,
    required this.roleId,
    required this.isMuted,
    required this.isBanned,
    required this.permissionsOverrides,
  });

  @override
  List<Object?> get props => [
    userId,
    roleId,
    isMuted,
    isBanned,
    permissionsOverrides,
  ];

  factory ChatMemberModel.fromJson(Map<String, dynamic> json) =>
      _$ChatMemberModelFromJson(json);

  Map<String, dynamic> toJson() => _$ChatMemberModelToJson(this);
}

extension ChatMemberModelX on ChatMemberModel {
  ChatMemberEntity toEntity() {
    return ChatMemberEntity(
      userId: userId,
      roleId: roleId,
      isMuted: isMuted,
      isBanned: isBanned,
      permissionsOverrides: permissionsOverrides,
    );
  }
}

/// `MemberPresenceDTO` (api-docs §6.3).
@JsonSerializable(fieldRename: FieldRename.snake)
class MemberPresenceModel extends Equatable {
  final int userId;
  final bool isOnline;

  const MemberPresenceModel({required this.userId, required this.isOnline});

  @override
  List<Object?> get props => [userId, isOnline];

  factory MemberPresenceModel.fromJson(Map<String, dynamic> json) =>
      _$MemberPresenceModelFromJson(json);

  Map<String, dynamic> toJson() => _$MemberPresenceModelToJson(this);
}

extension MemberPresenceModelX on MemberPresenceModel {
  MemberPresenceEntity toEntity() =>
      MemberPresenceEntity(userId: userId, isOnline: isOnline);
}

/// `ListMembers` (api-docs §6.3) — cursor-paginated member page.
@JsonSerializable(fieldRename: FieldRename.snake)
class ListMembersModel extends Equatable {
  @JsonKey(defaultValue: <ChatMemberModel>[])
  final List<ChatMemberModel> members;
  final bool hasNext;
  final int? nextUserId;

  /// Empty unless the request asked for `include_presence=true`.
  @JsonKey(defaultValue: <MemberPresenceModel>[])
  final List<MemberPresenceModel> presence;

  const ListMembersModel({
    required this.members,
    required this.hasNext,
    required this.nextUserId,
    required this.presence,
  });

  @override
  List<Object?> get props => [members, hasNext, nextUserId, presence];

  factory ListMembersModel.fromJson(Map<String, dynamic> json) =>
      _$ListMembersModelFromJson(json);

  Map<String, dynamic> toJson() => _$ListMembersModelToJson(this);
}
