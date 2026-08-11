import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

part 'reaction_model.g.dart';

/// `ReactionSummaryDTO` (api-docs §6.7.3).
@JsonSerializable(fieldRename: FieldRename.snake)
class ReactionSummaryModel extends Equatable {
  final String emoji;
  final int count;

  /// Defaulted to `false` rather than required: the field is always sent by
  /// the endpoint, but a chip that wrongly claims to be *ours* would let the
  /// user "un-react" something they never reacted to, so the safe default is
  /// the one that renders an inert chip.
  @JsonKey(defaultValue: false)
  final bool reactedByMe;

  const ReactionSummaryModel({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });

  @override
  List<Object?> get props => [emoji, count, reactedByMe];

  factory ReactionSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$ReactionSummaryModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReactionSummaryModelToJson(this);
}

extension ReactionSummaryModelX on ReactionSummaryModel {
  ReactionSummaryEntity toEntity() => ReactionSummaryEntity(
    emoji: emoji,
    count: count,
    reactedByMe: reactedByMe,
  );
}

/// `ReactionUserDTO` (api-docs §6.7.3).
@JsonSerializable(fieldRename: FieldRename.snake)
class ReactionUserModel extends Equatable {
  final int userId;
  final String emoji;

  const ReactionUserModel({required this.userId, required this.emoji});

  @override
  List<Object?> get props => [userId, emoji];

  factory ReactionUserModel.fromJson(Map<String, dynamic> json) =>
      _$ReactionUserModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReactionUserModelToJson(this);
}

extension ReactionUserModelX on ReactionUserModel {
  ReactionUserEntity toEntity() =>
      ReactionUserEntity(userId: userId, emoji: emoji);
}

/// `MessageReactionsDTO` (api-docs §6.7.3) — the response of both modes of
/// `GET .../reactions/`; see [MessageReactionsEntity] for what distinguishes
/// them.
@JsonSerializable(fieldRename: FieldRename.snake)
class MessageReactionsModel extends Equatable {
  /// ⚠️ A plain string on the wire, not a typed UUID (api-docs §6.7.3).
  final String messageId;

  @JsonKey(defaultValue: <ReactionSummaryModel>[])
  final List<ReactionSummaryModel> summaries;

  /// Echo of the `?emoji=` query parameter; `null` in summary-only mode.
  final String? emoji;

  /// Empty unless the request carried `?emoji=`.
  @JsonKey(defaultValue: <ReactionUserModel>[])
  final List<ReactionUserModel> users;

  @JsonKey(defaultValue: false)
  final bool hasNext;

  final int? nextUserId;

  const MessageReactionsModel({
    required this.messageId,
    required this.summaries,
    required this.emoji,
    required this.users,
    required this.hasNext,
    required this.nextUserId,
  });

  @override
  List<Object?> get props => [
    messageId,
    summaries,
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
    summaries: summaries.map((s) => s.toEntity()).toList(),
    emoji: emoji,
    users: users.map((u) => u.toEntity()).toList(),
    hasNext: hasNext,
    // Only meaningful while there is a next page; the backend already sends
    // `null` otherwise, but this makes a stale cursor impossible.
    nextUserId: hasNext ? nextUserId : null,
  );
}
