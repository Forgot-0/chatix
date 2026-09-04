import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

part 'reaction_model.g.dart';

/// `ReactionGroupDTO` (api-docs §6.7.3).
@JsonSerializable(fieldRename: FieldRename.snake)
class ReactionGroupModel extends Equatable {
  final String emoji;
  final int count;

  /// Monotonic group version (§6.7.3) — used downstream to drop out-of-order
  /// WS snapshots. Defaulted to 0 rather than required so an older backend
  /// that doesn't send it still parses; a constant version simply means the
  /// idempotency check never rejects anything, which is the pre-versioning
  /// behaviour.
  @JsonKey(defaultValue: 0)
  final int version;

  /// Defaulted to `false` rather than required: the field is always sent by
  /// the endpoint, but a chip that wrongly claims to be *ours* would let the
  /// user "un-react" something they never reacted to, so the safe default is
  /// the one that renders an inert chip.
  ///
  /// ⚠️ Always `false` inside a `reaction_update` snapshot (§6.7.6) — that is
  /// a property of the event, not a parse failure. See
  /// `MessageReactionsEntity.applySnapshot`.
  @JsonKey(defaultValue: false)
  final bool reactedByMe;

  /// Up to `REACTION_RECENT_USERS_LIMIT` (3) recent reactor ids (§6.7.3).
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
    // Trimmed to the documented cap so a backend that over-sends can't grow
    // the avatar stack the chip is laid out for.
    recentUserIds: recentUserIds
        .take(ReactionLimits.recentUsersLimit)
        .toList(),
  );
}

/// `MessageReactionsDTO` (api-docs §6.7.3) — the response of both modes of
/// `GET .../reactions/`; see [MessageReactionsEntity] for what distinguishes
/// them.
@JsonSerializable(fieldRename: FieldRename.snake)
class MessageReactionsModel extends Equatable {
  /// ⚠️ A plain string on the wire, not a typed UUID (§6.7.3).
  final String messageId;

  @JsonKey(defaultValue: <ReactionGroupModel>[])
  final List<ReactionGroupModel> groups;

  /// Echo of the `?emoji=` query parameter; `null` in summary-only mode.
  final String? emoji;

  /// ⚠️ Bare `user_id`s (§6.7.3), not objects. Empty unless the request
  /// carried `?emoji=`.
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
    // Only meaningful while there is a next page; the backend already sends
    // `null` otherwise, but this makes a stale cursor impossible.
    nextUserId: hasNext ? nextUserId : null,
  );
}

/// `payload.reaction` of the `reaction_update` WS event — `ReactionUpdateWSDTO`
/// (api-docs §6.7.6).
///
/// Modelled as a data-layer DTO rather than a `core/websocket` type for the
/// same reason `MessageModel` is: the WS parser keeps the block as a raw JSON
/// map so `core/` need not import `features/chat`, and the feature decodes it
/// here with the same generated decoder it uses everywhere else.
///
/// ⚠️ [groups] is a **complete snapshot**, never a delta, and its
/// `reacted_by_me` flags are always `false` (§6.7.6) — fold it in through
/// `MessageReactionsEntity.applySnapshot`, which restores the local flags.
@JsonSerializable(fieldRename: FieldRename.snake)
class ReactionUpdateModel extends Equatable {
  final String messageId;
  final String chatId;

  /// Who caused the change. Compared against the signed-in user id to decide
  /// whether the snapshot's own-membership beats the local optimistic flags —
  /// see `applySnapshot`.
  final int actorId;

  /// `"add" | "remove" | "replace" | "update"` — see [ReactionAction].
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
