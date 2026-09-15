import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
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

/// The repository that decides where an answer comes from.
///
/// Reads that can be answered from the device are answered from the device
/// and then repeated over the network — the `local*` methods are the first
/// half of that, and every network read that succeeds writes what it learned
/// back down on its way out. Nothing above this line knows there is a store
/// at all: a use case asks for messages, and whether the answer travelled is
/// not part of the question.
class ChatRepositoryImpl implements ChatRepository {
  final ChatRestDataSource _remote;
  final ChatLocalDataSource _local;

  ChatRepositoryImpl(this._remote, this._local);

  /// How many messages of one chat are written back per page.
  ///
  /// The page size the screen opens with is 30 (api-docs §5.4); keeping a
  /// little more than that means the first paint from the cache is a full
  /// screen with room to scroll, not a screenful exactly.
  static const int localMessageWindow = 60;

  @override
  Future<Either<Failure, ChatsPage>> getChats({
    int limit = 50,
    String? lastChatId,
    DateTime? lastActivityAt,
    bool archived = false,
  }) async {
    final result = await _remote.fetchChats(
      limit: limit,
      lastChatId: lastChatId,
      lastActivityAt: lastActivityAt,
      archived: archived,
    );

    // Only the first page is kept. It is the one a cold start draws, and the
    // ones after it are scroll-back that the list will ask for again anyway
    // — storing them would mean keeping a cursor chain consistent for no
    // gain.
    final isFirstPage = lastChatId == null && lastActivityAt == null;
    final model = result.getRight().toNullable();
    if (isFirstPage && model != null) {
      await _rememberChatList(model, archived: archived);
    }

    return result.map(_toChatsPage);
  }

  @override
  Future<Either<Failure, ChatStateEntity>> updateChatState(
    String chatId, {
    bool? pinned,
    bool? archived,
    DateTime? notificationsMutedUntil,
    bool clearNotificationsMutedUntil = false,
    String? draft,
    bool clearDraft = false,
  }) async {
    final result = await _remote.updateChatState(
      chatId,
      pinned: pinned,
      archived: archived,
      notificationsMutedUntil: notificationsMutedUntil,
      clearNotificationsMutedUntil: clearNotificationsMutedUntil,
      draft: draft,
      clearDraft: clearDraft,
    );
    return result.map((model) => model.toEntity());
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
  Future<Either<Failure, void>> deleteChat(String chatId) async {
    final result = await _remote.deleteChat(chatId);
    if (result.isRight()) await _local.forgetChat(chatId);
    return result;
  }

  @override
  Future<Either<Failure, void>> joinChat(String chatId) =>
      _remote.joinChat(chatId);

  @override
  Future<Either<Failure, void>> leaveChat(String chatId) async {
    final result = await _remote.leaveChat(chatId);
    if (result.isRight()) await _local.forgetChat(chatId);
    return result;
  }

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
    await _rememberPage(chatId, result.getRight().toNullable());
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
    await _rememberPage(chatId, result.getRight().toNullable());
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
    await _rememberOne(chatId, result.getRight().toNullable());
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
    await _rememberOne(chatId, result.getRight().toNullable());
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> deleteMessage(
    String chatId,
    String messageId,
  ) async {
    final result = await _remote.deleteMessage(chatId, messageId);
    if (result.isRight()) await _local.deleteMessage(chatId, messageId);
    return result;
  }

  @override
  Future<Either<Failure, MessageEntity>> forwardMessage({
    required String sourceChatId,
    required String sourceMessageId,
    required String targetChatId,
    String? comment,
    String? idempotencyKey,
  }) async {
    final result = await _remote.forwardMessage(
      sourceChatId: sourceChatId,
      sourceMessageId: sourceMessageId,
      targetChatId: targetChatId,
      comment: comment,
      idempotencyKey: idempotencyKey,
    );
    await _rememberOne(targetChatId, result.getRight().toNullable());
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> markRead(String chatId, int messageSeq) async {
    final result = await _remote.markRead(chatId, messageSeq);
    if (result.isRight()) {
      await _rememberSeq(chatId, reportedSeq: messageSeq);
    }
    return result;
  }

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

  Future<void> _rememberChatList(
    ListChatsModel model, {
    required bool archived,
  }) async {
    await _local.writeChatList(
      CachedChatList(
        chats: [for (final chat in model.chats) chat.toJson()],
        hasNext: model.hasNext,
        nextDate: model.nextDate,
        nextChatId: model.nextChatId,
        savedAt: DateTime.now(),
      ),
      archived: archived,
    );
  }

  Future<void> _rememberPage(String chatId, MessagesModel? model) async {
    if (model == null || model.messages.isEmpty) return;
    await _remember(chatId, [
      for (final message in model.messages) message.toEntity(),
    ]);
  }

  Future<void> _rememberOne(String chatId, MessageModel? model) async {
    if (model == null) return;
    await _remember(chatId, [model.toEntity()]);
  }

  /// Writes a page down on its way to the caller.
  ///
  /// The store is shared with [ChatLocalRepository], which is what reads it
  /// back: a fetch here is what fills the cache a screen opens on.
  Future<void> _remember(String chatId, List<MessageEntity> messages) async {
    if (messages.isEmpty) return;

    await _local.writeMessages(chatId, [
      for (final message in messages) message.toModel().toJson(),
    ]);

    var highest = messages.first.seq;
    for (final message in messages) {
      if (message.seq > highest) highest = message.seq;
    }
    await _rememberSeq(chatId, lastSeq: highest);

    await _rememberAttachments(messages);
  }

  Future<void> _rememberSeq(
    String chatId, {
    int? lastSeq,
    int? reportedSeq,
  }) async {
    if (chatId.isEmpty) return;

    final known =
        _local.readReadState(chatId) ??
        ChatReadState(
          chatId: chatId,
          lastSeq: 0,
          reportedSeq: 0,
          updatedAt: DateTime.now(),
        );

    // Both cursors only ever move forward. A refetch of an older window, or
    // a read report racing a later one, must not walk them back — a cursor
    // that went backwards would replay history the reader has already seen.
    final nextLast = lastSeq != null && lastSeq > known.lastSeq
        ? lastSeq
        : known.lastSeq;
    final nextReported = reportedSeq != null && reportedSeq > known.reportedSeq
        ? reportedSeq
        : known.reportedSeq;

    if (nextLast == known.lastSeq && nextReported == known.reportedSeq) return;

    await _local.writeReadState(
      known.copyWith(
        lastSeq: nextLast,
        reportedSeq: nextReported,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Files what is known about each attachment, keyed by `s3_key`.
  ///
  /// Not the bytes — those are the file cache's business — but the sizes and
  /// types behind them, which is what lets the media a chat is holding be
  /// measured and trimmed without opening every file to ask.
  Future<void> _rememberAttachments(List<MessageEntity> messages) async {
    for (final message in messages) {
      for (final attachment in message.attachments) {
        if (attachment.s3Key.isEmpty) continue;
        await _local.writeAttachment(
          CachedAttachment(
            s3Key: attachment.s3Key,
            chatId: attachment.chatId,
            messageId: attachment.messageId ?? message.id,
            mimeType: attachment.mimeType,
            originalFilename: attachment.originalFilename,
            size: attachment.size,
            cachedAt: DateTime.now(),
          ),
        );
      }
    }
  }

}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    ref.watch(chatRestDataSourceProvider),
    ref.watch(chatLocalDataSourceProvider),
  );
});
