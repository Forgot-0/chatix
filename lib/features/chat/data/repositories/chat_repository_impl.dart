import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/chat/data/models/attachment_model.dart';
import 'package:chatix/features/chat/data/models/call_token_model.dart';
import 'package:chatix/features/chat/data/models/chat_member_model.dart';
import 'package:chatix/features/chat/data/models/chat_model.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/data/models/reaction_model.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRestDataSource _remote;

  ChatRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, ChatsPage>> getChats({
    int limit = 50,
    String? lastChatId,
    DateTime? lastActivityAt,
  }) async {
    final result = await _remote.fetchChats(
      limit: limit,
      lastChatId: lastChatId,
      lastActivityAt: lastActivityAt,
    );
    return result.map(_toChatsPage);
  }

  @override
  Future<Either<Failure, ChatEntity>> createChat({
    String? name,
    String? description,
    ChatType chatType = ChatType.direct,
    List<int> memberIds = const [],
    bool isPublic = false,
    bool adminOnly = false,
    int slowModeSeconds = 0,
    Map<String, bool>? permissions,
  }) async {
    final result = await _remote.createChat(
      name: name,
      description: description,
      chatType: chatType,
      memberIds: memberIds,
      isPublic: isPublic,
      adminOnly: adminOnly,
      slowModeSeconds: slowModeSeconds,
      permissions: permissions,
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, ChatEntity>> getChat(String chatId) async {
    final result = await _remote.fetchChat(chatId);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, ChatEntity>> updateChat(
    String chatId, {
    String? name,
    String? description,
    bool? isPublic,
    bool? adminOnly,
    int? slowModeSeconds,
    Map<String, bool>? permissions,
    ChatReactionsMode? reactionsMode,
    List<String>? allowedReactions,
  }) async {
    final result = await _remote.updateChat(
      chatId,
      name: name,
      description: description,
      isPublic: isPublic,
      adminOnly: adminOnly,
      slowModeSeconds: slowModeSeconds,
      permissions: permissions,
      reactionsMode: reactionsMode,
      allowedReactions: allowedReactions,
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> deleteChat(String chatId) =>
      _remote.deleteChat(chatId);

  @override
  Future<Either<Failure, void>> joinChat(String chatId) =>
      _remote.joinChat(chatId);

  @override
  Future<Either<Failure, void>> leaveChat(String chatId) =>
      _remote.leaveChat(chatId);

  @override
  Future<Either<Failure, MembersPage>> getMembers(
    String chatId, {
    int limit = 50,
    int? cursorUserId,
    bool includePresence = false,
  }) async {
    final result = await _remote.fetchMembers(
      chatId,
      limit: limit,
      cursorUserId: cursorUserId,
      includePresence: includePresence,
    );
    return result.map(_toMembersPage);
  }

  @override
  Future<Either<Failure, void>> addMember(
    String chatId,
    int userId, {
    int roleId = 5,
  }) => _remote.addMember(chatId, userId, roleId: roleId);

  @override
  Future<Either<Failure, void>> changeMemberRole(
    String chatId,
    int userId,
    int roleId,
  ) => _remote.changeMemberRole(chatId, userId, roleId);

  @override
  Future<Either<Failure, void>> banMember(
    String chatId,
    int userId, {
    String? reason,
    DateTime? bannedTo,
  }) => _remote.banMember(chatId, userId, reason: reason, bannedTo: bannedTo);

  @override
  Future<Either<Failure, void>> kickMember(String chatId, int userId) =>
      _remote.kickMember(chatId, userId);

  @override
  Future<Either<Failure, MessagesPage>> getMessages(
    String chatId, {
    int limit = 30,
    int? cursorMessageSeq,
  }) async {
    final result = await _remote.fetchMessages(
      chatId,
      limit: limit,
      cursorMessageSeq: cursorMessageSeq,
    );
    return result.map(_toMessagesPage);
  }

  @override
  Future<Either<Failure, MessagesPage>> getMessagesContext(
    String chatId,
    int targetSeq, {
    int limit = 40,
  }) async {
    final result = await _remote.fetchMessagesContext(
      chatId,
      targetSeq,
      limit: limit,
    );
    return result.map(_toMessagesPage);
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMessage(
    String chatId, {
    String? content,
    String? replyToId,
    MessageType? messageType,
    List<String>? uploadTokens,
    String? idempotencyKey,
  }) async {
    final result = await _remote.sendMessage(
      chatId,
      content: content,
      replyToId: replyToId,
      messageType: messageType,
      uploadTokens: uploadTokens,
      idempotencyKey: idempotencyKey,
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, MessageEntity>> getMessage(
    String chatId,
    String messageId,
  ) async {
    final result = await _remote.fetchMessage(chatId, messageId);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, MessageEntity>> editMessage(
    String chatId,
    String messageId,
    String content,
  ) async {
    final result = await _remote.editMessage(chatId, messageId, content);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> deleteMessage(
    String chatId,
    String messageId,
  ) => _remote.deleteMessage(chatId, messageId);

  @override
  Future<Either<Failure, MessageEntity>> forwardMessage({
    required String sourceChatId,
    required String sourceMessageId,
    required String targetChatId,
    String? comment,
  }) async {
    final result = await _remote.forwardMessage(
      sourceChatId: sourceChatId,
      sourceMessageId: sourceMessageId,
      targetChatId: targetChatId,
      comment: comment,
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> markRead(String chatId, int messageSeq) =>
      _remote.markRead(chatId, messageSeq);

  @override
  Future<Either<Failure, List<AttachmentUploadTicketEntity>>>
  requestAttachmentUpload(
    String chatId,
    List<AttachmentUploadRequestEntity> uploads,
  ) async {
    final result = await _remote.requestAttachmentUpload(chatId, uploads);
    return result.map(
      (tickets) => tickets
          .map<AttachmentUploadTicketEntity>((ticket) => ticket.toEntity())
          .toList(),
    );
  }

  @override
  Future<Either<Failure, void>> confirmAttachmentUpload(
    String chatId,
    List<String> uploadTokens,
  ) => _remote.confirmAttachmentUpload(chatId, uploadTokens);

  @override
  Future<Either<Failure, AttachmentDownloadUrlEntity>> getAttachmentDownloadUrl(
    String chatId,
    String messageId,
    String attachmentId,
  ) async {
    final result = await _remote.fetchAttachmentDownloadUrl(
      chatId,
      messageId,
      attachmentId,
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, CallTokenEntity>> joinCall(String chatId) async {
    final result = await _remote.joinCall(chatId);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> muteCallParticipant(
    String chatId,
    int userId,
    bool muted,
  ) => _remote.muteCallParticipant(chatId, userId, muted);

  @override
  Future<Either<Failure, void>> setReaction(
    String chatId,
    String messageId,
    String emoji,
  ) => _remote.setReaction(chatId, messageId, emoji);

  @override
  Future<Either<Failure, void>> removeReaction(
    String chatId,
    String messageId,
    String emoji,
  ) => _remote.removeReaction(chatId, messageId, emoji);

  @override
  Future<Either<Failure, void>> replaceReactions(
    String chatId,
    String messageId,
    List<String> emojis,
  ) => _remote.replaceReactions(chatId, messageId, emojis);

  @override
  Future<Either<Failure, void>> clearReactions(
    String chatId,
    String messageId,
  ) => _remote.clearReactions(chatId, messageId);

  @override
  Future<Either<Failure, MessageReactionsEntity>> getReactions(
    String chatId,
    String messageId, {
    String? emoji,
    int limit = 50,
    int? cursorUserId,
  }) async {
    final result = await _remote.fetchReactions(
      chatId,
      messageId,
      emoji: emoji,
      limit: limit,
      cursorUserId: cursorUserId,
    );
    return result.map((model) => model.toEntity());
  }

  ChatsPage _toChatsPage(ListChatsModel model) {
    return ChatsPage(
      chats: model.chats.map<ChatEntity>((chat) => chat.toEntity()).toList(),
      hasNext: model.hasNext,
      nextDate: model.nextDate,
      nextChatId: model.nextChatId,
    );
  }

  MessagesPage _toMessagesPage(MessagesModel model) {
    return MessagesPage(
      messages: model.messages
          .map<MessageEntity>((message) => message.toEntity())
          .toList(),
      nextCursor: model.nextCursor,
      hasNext: model.hasNext,
    );
  }

  MembersPage _toMembersPage(ListMembersModel model) {
    return MembersPage(
      members: model.members
          .map<ChatMemberEntity>((member) => member.toEntity())
          .toList(),
      hasNext: model.hasNext,
      nextUserId: model.nextUserId,
      presence: model.presence
          .map<MemberPresenceEntity>((entry) => entry.toEntity())
          .toList(),
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(chatRestDataSourceProvider));
});
