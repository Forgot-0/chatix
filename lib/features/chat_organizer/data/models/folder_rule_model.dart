import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';

part 'folder_rule_model.g.dart';

/// One stored rule, flattened.
///
/// The domain side is a sealed union; on disk it is a single wide record with
/// a `type` discriminator, because that is what survives a rule gaining a
/// field without invalidating everything written before it. Fields that do
/// not belong to a type are simply absent.
@JsonSerializable(fieldRename: FieldRename.snake)
class FolderRuleModel extends Equatable {
  const FolderRuleModel({
    required this.type,
    this.chatTypes,
    this.expected,
    this.days,
    this.userId,
    this.label,
  });

  factory FolderRuleModel.fromJson(Map<String, dynamic> json) =>
      _$FolderRuleModelFromJson(json);

  /// A [FolderRuleKind.wire] value.
  final String type;

  final List<String>? chatTypes;
  final bool? expected;
  final int? days;
  final int? userId;
  final String? label;

  factory FolderRuleModel.fromEntity(FolderRule rule) {
    return switch (rule) {
      ChatTypeRule(:final types) => FolderRuleModel(
        type: rule.kind.wire,
        chatTypes: types.map((t) => t.wire).toList(),
      ),
      UnreadRule(:final expected) => FolderRuleModel(
        type: rule.kind.wire,
        expected: expected,
      ),
      PinnedRule(:final expected) => FolderRuleModel(
        type: rule.kind.wire,
        expected: expected,
      ),
      NoReplyFromMeRule(:final days) => FolderRuleModel(
        type: rule.kind.wire,
        days: days,
      ),
      MemberRule(:final userId, :final label) => FolderRuleModel(
        type: rule.kind.wire,
        userId: userId,
        label: label,
      ),
    };
  }

  /// The rule this stands for, or null when the file was written by a build
  /// that knew a kind this one does not.
  FolderRule? toEntity() {
    switch (FolderRuleKind.fromWire(type)) {
      case FolderRuleKind.chatType:
        final types = (chatTypes ?? const <String>[])
            .map(ChatType.fromWire)
            .toSet();
        if (types.isEmpty) return null;
        return ChatTypeRule(types);

      case FolderRuleKind.unread:
        return UnreadRule(expected: expected ?? true);

      case FolderRuleKind.pinned:
        return PinnedRule(expected: expected ?? true);

      case FolderRuleKind.noReplyFromMe:
        final value = days ?? 0;
        return NoReplyFromMeRule(
          days: value.clamp(0, NoReplyFromMeRule.maxDays),
        );

      case FolderRuleKind.member:
        final id = userId;
        if (id == null) return null;
        return MemberRule(userId: id, label: label);

      case null:
        return null;
    }
  }

  Map<String, dynamic> toJson() => _$FolderRuleModelToJson(this);

  @override
  List<Object?> get props => [type, chatTypes, expected, days, userId, label];
}
