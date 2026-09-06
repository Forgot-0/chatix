import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

abstract class ChatRepository {

  Future<Either<Failure, ChatsPage>> getChats({
    int limit = 50,
    String? lastChatId,
    DateTime? lastActivityAt,
  });

  Future<Either<Failure, ChatEntity>> createChat({
    String? name,
    String? description,
    ChatType chatType = ChatType.direct,
    List<int> memberIds = const [],
    bool isPublic = false,
    bool adminOnly = false,
    int slowModeSeconds = 0,
    Map<String, bool>? permissions,
  });

  Future<Either<Failure, ChatEntity>> getChat(String chatId);

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
  });

  Future<Either<Failure, void>> deleteChat(String chatId);

  Future<Either<Failure, void>> joinChat(String chatId);

  Future<Either<Failure, void>> leaveChat(String chatId);

  Future<Either<Failure, MembersPage>> getMembers(
    String chatId, {
    int limit = 50,
    int? cursorUserId,
    bool includePresence = false,
  });

  Future<Either<Failure, void>> addMember(
    String chatId,
    int userId, {
    int roleId = 5,
  });

  Future<Either<Failure, void>> changeMemberRole(
    String chatId,
    int userId,
    int roleId,
  );

  Future<Either<Failure, void>> banMember(
    String chatId,
    int userId, {
    String? reason,
    DateTime? bannedTo,
  });

  Future<Either<Failure, void>> kickMember(String chatId, int userId);

  Future<Either<Failure, MessagesPage>> getMessages(
    String chatId, {
    int limit = 30,
    int? cursorMessageSeq,
  });

  Future<Either<Failure, MessagesPage>> getMessagesContext(
    String chatId,
    int targetSeq, {
    int limit = 40,
  });

  Future<Either<Failure, MessageEntity>> sendMessage(
    String chatId, {
    String? content,
    String? replyToId,
    MessageType? messageType,
    List<String>? uploadTokens,
    String? idempotencyKey,
  });

  Future<Either<Failure, MessageEntity>> getMessage(
    String chatId,
    String messageId,
  );

  Future<Either<Failure, MessageEntity>> editMessage(
    String chatId,
    String messageId,
    String content,
  );

  Future<Either<Failure, void>> deleteMessage(String chatId, String messageId);

  Future<Either<Failure, MessageEntity>> forwardMessage({
    required String sourceChatId,
    required String sourceMessageId,
    required String targetChatId,
    String? comment,
  });

  Future<Either<Failure, void>> markRead(String chatId, int messageSeq);

  Future<Either<Failure, List<AttachmentUploadTicketEntity>>>
  requestAttachmentUpload(
    String chatId,
    List<AttachmentUploadRequestEntity> uploads,
  );

  Future<Either<Failure, void>> confirmAttachmentUpload(
    String chatId,
    List<String> uploadTokens,
  );

  Future<Either<Failure, AttachmentDownloadUrlEntity>>
  getAttachmentDownloadUrl(
    String chatId,
    String messageId,
    String attachmentId,
  );

  Future<Either<Failure, CallTokenEntity>> joinCall(String chatId);

  Future<Either<Failure, void>> muteCallParticipant(
    String chatId,
    int userId,
    bool muted,
  );

  Future<Either<Failure, void>> setReaction(
    String chatId,
    String messageId,
    String emoji,
  );

  Future<Either<Failure, void>> removeReaction(
    String chatId,
    String messageId,
    String emoji,
  );

  Future<Either<Failure, void>> replaceReactions(
    String chatId,
    String messageId,
    List<String> emojis,
  );

  Future<Either<Failure, void>> clearReactions(String chatId, String messageId);

  Future<Either<Failure, MessageReactionsEntity>> getReactions(
    String chatId,
    String messageId, {
    String? emoji,
    int limit = 50,
    int? cursorUserId,
  });
}
