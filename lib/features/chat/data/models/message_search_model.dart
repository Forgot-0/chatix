import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';

part 'message_search_model.g.dart';

/// The chat preview that rides along with every hit, so a result from a chat
/// the list has never loaded still has a name and a face (api-docs §5.4.1).
@JsonSerializable(fieldRename: FieldRename.snake)
class MessageSearchChatModel extends Equatable {
  final String id;
  final String type;
  final String? name;
  final String? avatarUrl;
  final String? avatarS3Key;

  const MessageSearchChatModel({
    required this.id,
    required this.type,
    required this.name,
    required this.avatarUrl,
    required this.avatarS3Key,
  });

  @override
  List<Object?> get props => [id, type, name, avatarUrl, avatarS3Key];

  factory MessageSearchChatModel.fromJson(Map<String, dynamic> json) =>
      _$MessageSearchChatModelFromJson(json);

  Map<String, dynamic> toJson() => _$MessageSearchChatModelToJson(this);
}

extension MessageSearchChatModelX on MessageSearchChatModel {
  MessageSearchChat toEntity() => MessageSearchChat(
    id: id,
    type: ChatType.fromWire(type),
    name: name,
    avatarUrl: avatarUrl,
    avatarS3Key: avatarS3Key,
  );
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MessageSearchItemModel extends Equatable {
  final MessageModel message;
  final MessageSearchChatModel? chat;

  const MessageSearchItemModel({required this.message, required this.chat});

  @override
  List<Object?> get props => [message, chat];

  factory MessageSearchItemModel.fromJson(Map<String, dynamic> json) =>
      _$MessageSearchItemModelFromJson(json);

  Map<String, dynamic> toJson() => _$MessageSearchItemModelToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MessageSearchModel extends Equatable {
  final bool hasNext;

  @JsonKey(defaultValue: <MessageSearchItemModel>[])
  final List<MessageSearchItemModel> items;

  /// Filled only when [hasNext] (api-docs §5.4.1).
  final String? nextMessageId;

  const MessageSearchModel({
    required this.hasNext,
    required this.items,
    required this.nextMessageId,
  });

  @override
  List<Object?> get props => [hasNext, items, nextMessageId];

  factory MessageSearchModel.fromJson(Map<String, dynamic> json) =>
      _$MessageSearchModelFromJson(json);

  Map<String, dynamic> toJson() => _$MessageSearchModelToJson(this);
}

extension MessageSearchModelX on MessageSearchModel {
  /// Turns a page into hits, building each snippet against [query].
  MessageSearchResult toEntity(String query) {
    final hits = <MessageSearchHit>[];

    for (final item in items) {
      final hit = MessageSearchHit.of(
        item.message.toEntity(),
        query,
        chat: item.chat?.toEntity(),
      );
      if (hit != null) hits.add(hit);
    }

    return MessageSearchResult(
      hits: hits,
      source: MessageSearchSource.server,
      hasNext: hasNext,
      nextMessageId: nextMessageId,
    );
  }
}
