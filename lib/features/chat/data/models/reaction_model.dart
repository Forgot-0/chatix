import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

part 'reaction_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ReactionGroupModel extends Equatable {
  final String emoji;
  final int count;

  @JsonKey(defaultValue: 0)
  final int version;

  @JsonKey(defaultValue: false)
  final bool reactedByMe;

  @JsonKey(defaultValue: <int>[])
  final List<int> recentUserIds;

  const ReactionGroupModel({
    required this.emoji,
    required this.count,
    required this.version,
    required this.reactedByMe,
    required this.recentUserIds,
  });

  @override
  List<Object?> get props => [
    emoji,
    count,
    version,
    reactedByMe,
    recentUserIds,
  ];

  factory ReactionGroupModel.fromJson(Map<String, dynamic> json) =>
      _$ReactionGroupModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReactionGroupModelToJson(this);
}

extension ReactionGroupModelX on ReactionGroupModel {
  ReactionGroupEntity toEntity() => ReactionGroupEntity(
    emoji: emoji,
    count: count,
    version: version,
    reactedByMe: reactedByMe,
    recentUserIds: recentUserIds.take(ReactionLimits.recentUsersLimit).toList(),
  );
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MessageReactionsModel extends Equatable {
  final String messageId;

  @JsonKey(defaultValue: <ReactionGroupModel>[])
  final List<ReactionGroupModel> groups;

  final String? emoji;

  @JsonKey(defaultValue: <int>[])
  final List<int> users;

  @JsonKey(defaultValue: false)
  final bool hasNext;

  final int? nextUserId;

  const MessageReactionsModel({
    required this.messageId,
    required this.groups,
    required this.emoji,
    required this.users,
    required this.hasNext,
    required this.nextUserId,
  });

  @override
  List<Object?> get props => [
    messageId,
    groups,
    emoji,
    users,
    hasNext,
    nextUserId,
  ];

  factory MessageReactionsModel.fromJson(Map<String, dynamic> json) =>
      _$MessageReactionsModelFromJson(json);

  Map<String, dynamic> toJson() => _$MessageReactionsModelToJson(this);
}

extension MessageReactionsModelX on MessageReactionsModel {
  MessageReactionsEntity toEntity() => MessageReactionsEntity(
    messageId: messageId,
    groups: groups.map((g) => g.toEntity()).toList(),
    emoji: emoji,
    users: users,
    hasNext: hasNext,
    nextUserId: hasNext ? nextUserId : null,
  );
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ReactionUpdateModel extends Equatable {
  final String messageId;
  final String chatId;

  final int actorId;

  final String action;

  @JsonKey(defaultValue: <ReactionGroupModel>[])
  final List<ReactionGroupModel> groups;

  const ReactionUpdateModel({
    required this.messageId,
    required this.chatId,
    required this.actorId,
    required this.action,
    required this.groups,
  });

  @override
  List<Object?> get props => [messageId, chatId, actorId, action, groups];

  factory ReactionUpdateModel.fromJson(Map<String, dynamic> json) =>
      _$ReactionUpdateModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReactionUpdateModelToJson(this);
}

extension ReactionUpdateModelX on ReactionUpdateModel {
  ReactionAction get parsedAction => ReactionAction.fromWire(action);

  List<ReactionGroupEntity> toGroups() =>
      groups.map((g) => g.toEntity()).toList();
}
