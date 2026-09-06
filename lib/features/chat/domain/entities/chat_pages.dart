import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

class ChatsPage extends Equatable {
  final List<ChatEntity> chats;

  final bool hasNext;

  final String? nextDate;

  final String? nextChatId;

  const ChatsPage({
    required this.chats,
    required this.hasNext,
    required this.nextDate,
    required this.nextChatId,
  });

  bool get canLoadMore => hasNext && (nextChatId != null || nextDate != null);

  @override
  List<Object?> get props => [chats, hasNext, nextDate, nextChatId];
}

class MessagesPage extends Equatable {
  final List<MessageEntity> messages;

  final int? nextCursor;

  final bool hasNext;

  const MessagesPage({
    required this.messages,
    required this.nextCursor,
    required this.hasNext,
  });

  bool get canLoadMore => hasNext && nextCursor != null;

  @override
  List<Object?> get props => [messages, nextCursor, hasNext];
}

class MembersPage extends Equatable {
  final List<ChatMemberEntity> members;

  final bool hasNext;

  final int? nextUserId;

  final List<MemberPresenceEntity> presence;

  const MembersPage({
    required this.members,
    required this.hasNext,
    required this.nextUserId,
    this.presence = const [],
  });

  bool get canLoadMore => hasNext && nextUserId != null;

  bool? presenceOf(int userId) {
    for (final entry in presence) {
      if (entry.userId == userId) return entry.isOnline;
    }
    return null;
  }

  @override
  List<Object?> get props => [members, hasNext, nextUserId, presence];
}
