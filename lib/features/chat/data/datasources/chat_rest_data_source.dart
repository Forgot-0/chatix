import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/chat/data/models/attachment_model.dart';
import 'package:chatix/features/chat/data/models/call_token_model.dart';
import 'package:chatix/features/chat/data/models/chat_member_model.dart';
import 'package:chatix/features/chat/data/models/chat_model.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/data/models/reaction_model.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

abstract class ChatRestDataSource {
  Future<Either<Failure, ListChatsModel>> fetchChats({
    int limit = 50,
    String? lastChatId,
    DateTime? lastActivityAt,
  });

  Future<Either<Failure, ChatModel>> createChat({
    String? name,
    String? description,
    ChatType chatType = ChatType.direct,
    List<int> memberIds = const [],
    bool isPublic = false,
    bool adminOnly = false,
    int slowModeSeconds = 0,
    Map<String, bool>? permissions,
  });

  Future<Either<Failure, ChatModel>> fetchChat(String chatId);

  Future<Either<Failure, ChatModel>> updateChat(
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

  Future<Either<Failure, ListMembersModel>> fetchMembers(
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

  Future<Either<Failure, MessagesModel>> fetchMessages(
    String chatId, {
    int limit = 30,
    int? cursorMessageSeq,
  });

  Future<Either<Failure, MessagesModel>> fetchMessagesContext(
    String chatId,
    int targetSeq, {
    int limit = 40,
  });

  Future<Either<Failure, MessageModel>> sendMessage(
    String chatId, {
    String? content,
    String? replyToId,
    MessageType? messageType,
    List<String>? uploadTokens,
    String? idempotencyKey,
  });

  Future<Either<Failure, MessageModel>> fetchMessage(
    String chatId,
    String messageId,
  );

  Future<Either<Failure, MessageModel>> editMessage(
    String chatId,
    String messageId,
    String content,
  );

  Future<Either<Failure, void>> deleteMessage(String chatId, String messageId);

  Future<Either<Failure, MessageModel>> forwardMessage({
    required String sourceChatId,
    required String sourceMessageId,
    required String targetChatId,
    String? comment,
    String? idempotencyKey,
  });

  Future<Either<Failure, void>> markRead(String chatId, int messageSeq);

  Future<Either<Failure, List<AttachmentUploadTicketModel>>>
  requestAttachmentUpload(
    String chatId,
    List<AttachmentUploadRequestEntity> uploads,
  );

  Future<Either<Failure, void>> confirmAttachmentUpload(
    String chatId,
    List<String> uploadTokens,
  );

  Future<Either<Failure, AttachmentDownloadUrlModel>>
  fetchAttachmentDownloadUrl(
    String chatId,
    String messageId,
    String attachmentId,
  );

  Future<Either<Failure, CallTokenModel>> joinCall(String chatId);

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

  Future<Either<Failure, MessageReactionsModel>> fetchReactions(
    String chatId,
    String messageId, {
    String? emoji,
    int limit = 50,
    int? cursorUserId,
  });
}

class ChatRestDataSourceImpl implements ChatRestDataSource {
  final ApiClient _apiClient;
  final Uuid _uuid;

  ChatRestDataSourceImpl(this._apiClient, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  @override
  Future<Either<Failure, ListChatsModel>> fetchChats({
    int limit = 50,
    String? lastChatId,
    DateTime? lastActivityAt,
  }) async {
    final result = await _apiClient.get(
      '/chats/',
      queryParameters: {
        'limit': limit,
        'last_chat_id': ?lastChatId,
        if (lastActivityAt != null)
          'last_activity_at': lastActivityAt.toUtc().toIso8601String(),
      },
    );
    return result.map(
      (data) => ListChatsModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, ChatModel>> createChat({
    String? name,
    String? description,
    ChatType chatType = ChatType.direct,
    List<int> memberIds = const [],
    bool isPublic = false,
    bool adminOnly = false,
    int slowModeSeconds = 0,
    Map<String, bool>? permissions,
  }) async {
    if (chatType == ChatType.direct && memberIds.length != 1) {
      return Left(
        InputFailure(
          message: memberIds.isEmpty
              ? 'A direct chat needs exactly one other participant, but none was selected'
              : 'A direct chat can only have one other participant, '
                    'but ${memberIds.length} were selected — '
                    'create a group chat instead',
        ),
      );
    }

    final result = await _apiClient.post(
      '/chats/',
      data: {
        'name': ?name,
        'description': ?description,
        'chat_type': chatType.wire,
        'member_ids': memberIds,
        'is_public': isPublic,
        'admin_only': adminOnly,
        'slow_mode_seconds': slowModeSeconds,
        'permissions': ?permissions,
      },
    );
    return result.map(
      (data) => ChatModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, ChatModel>> fetchChat(String chatId) async {
    final result = await _apiClient.get('/chats/$chatId/');
    return result.map(
      (data) => ChatModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, ChatModel>> updateChat(
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
    final result = await _apiClient.patch(
      '/chats/$chatId/',
      data: {
        'name': ?name,
        'description': ?description,
        'is_public': ?isPublic,
        'admin_only': ?adminOnly,
        'slow_mode_seconds': ?slowModeSeconds,
        'permissions': ?permissions,
        'reactions_mode': ?reactionsMode?.wire,
        'allowed_reactions': ?allowedReactions,
      },
    );
    return result.map(
      (data) => ChatModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, void>> deleteChat(String chatId) async {
    final result = await _apiClient.delete('/chats/$chatId/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> joinChat(String chatId) async {
    final result = await _apiClient.post('/chats/$chatId/join/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> leaveChat(String chatId) async {
    final result = await _apiClient.post('/chats/$chatId/leave/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, ListMembersModel>> fetchMembers(
    String chatId, {
    int limit = 50,
    int? cursorUserId,
    bool includePresence = false,
  }) async {
    final result = await _apiClient.get(
      '/chats/$chatId/members/',
      queryParameters: {
        'limit': limit,
        'cursor_user_id': ?cursorUserId,
        'include_presence': includePresence,
      },
    );
    return result.map(
      (data) => ListMembersModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, void>> addMember(
    String chatId,
    int userId, {
    int roleId = 5,
  }) async {
    final result = await _apiClient.post(
      '/chats/$chatId/members/',
      data: {'user_id': userId, 'role_id': roleId},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> changeMemberRole(
    String chatId,
    int userId,
    int roleId,
  ) async {
    final result = await _apiClient.patch(
      '/chats/$chatId/members/$userId/role/',
      data: {'role_id': roleId},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> banMember(
    String chatId,
    int userId, {
    String? reason,
    DateTime? bannedTo,
  }) async {
    final result = await _apiClient.patch(
      '/chats/$chatId/members/$userId/ban/',
      data: {
        'reason': ?reason,
        if (bannedTo != null) 'banned_to': bannedTo.toUtc().toIso8601String(),
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> kickMember(String chatId, int userId) async {
    final result = await _apiClient.delete('/chats/$chatId/members/$userId/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, MessagesModel>> fetchMessages(
    String chatId, {
    int limit = 30,
    int? cursorMessageSeq,
  }) async {
    final result = await _apiClient.get(
      '/chats/$chatId/messages/',
      queryParameters: {
        'limit': limit,
        'cursor_message_seq': ?cursorMessageSeq,
      },
    );
    return result.map(
      (data) => MessagesModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, MessagesModel>> fetchMessagesContext(
    String chatId,
    int targetSeq, {
    int limit = 40,
  }) async {
    final result = await _apiClient.get(
      '/chats/$chatId/messages/context/',
      queryParameters: {'target_seq': targetSeq, 'limit': limit},
    );
    return result.map(
      (data) => MessagesModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, MessageModel>> sendMessage(
    String chatId, {
    String? content,
    String? replyToId,
    MessageType? messageType,
    List<String>? uploadTokens,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();

    final result = await _apiClient.post(
      '/chats/$chatId/messages/',
      data: {
        'content': ?content,
        'reply_to_id': ?replyToId,
        if (messageType != null) 'message_type': messageType.wire,
        if (uploadTokens != null && uploadTokens.isNotEmpty)
          'upload_tokens': uploadTokens,
      },
      options: Options(headers: {'Idempotency-Key': key}),
    );
    return result.map(
      (data) => MessageModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, MessageModel>> fetchMessage(
    String chatId,
    String messageId,
  ) async {
    final result = await _apiClient.get('/chats/$chatId/messages/$messageId/');
    return result.map(
      (data) => MessageModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, MessageModel>> editMessage(
    String chatId,
    String messageId,
    String content,
  ) async {
    final result = await _apiClient.patch(
      '/chats/$chatId/messages/$messageId/',
      data: {'content': content},
    );
    return result.map(
      (data) => MessageModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, void>> deleteMessage(
    String chatId,
    String messageId,
  ) async {
    final result = await _apiClient.delete(
      '/chats/$chatId/messages/$messageId/',
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, MessageModel>> forwardMessage({
    required String sourceChatId,
    required String sourceMessageId,
    required String targetChatId,
    String? comment,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();

    final result = await _apiClient.post(
      '/chats/$targetChatId/messages/forward/',
      data: {
        'source_chat_id': sourceChatId,
        'source_message_id': sourceMessageId,
        'comment': ?comment,
      },
      options: Options(headers: {'Idempotency-Key': key}),
    );
    return result.map(
      (data) => MessageModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, void>> markRead(String chatId, int messageSeq) async {
    final result = await _apiClient.post(
      '/chats/$chatId/messages/read/',
      data: {'message_seq': messageSeq},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, List<AttachmentUploadTicketModel>>>
  requestAttachmentUpload(
    String chatId,
    List<AttachmentUploadRequestEntity> uploads,
  ) async {
    final result = await _apiClient.post(
      '/chats/$chatId/attachments/upload-requests/',
      data: {
        'uploads': uploads
            .map(
              (upload) => {
                'filename': upload.filename,
                'mime_type': upload.mimeType,
                'file_size': upload.fileSize,
                if (upload.attachmentType != null)
                  'attachment_type': upload.attachmentType!.wire,
              },
            )
            .toList(),
      },
    );
    return result.map(
      (data) => (data as List<dynamic>)
          .map(
            (item) => AttachmentUploadTicketModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<Either<Failure, void>> confirmAttachmentUpload(
    String chatId,
    List<String> uploadTokens,
  ) async {
    final result = await _apiClient.post(
      '/chats/$chatId/attachments/upload-requests/confirm/',
      data: {'upload_tokens': uploadTokens},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, AttachmentDownloadUrlModel>>
  fetchAttachmentDownloadUrl(
    String chatId,
    String messageId,
    String attachmentId,
  ) async {
    final result = await _apiClient.get(
      '/chats/$chatId/messages/$messageId/attachments/$attachmentId/download-url/',
    );
    return result.map(
      (data) =>
          AttachmentDownloadUrlModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, CallTokenModel>> joinCall(String chatId) async {
    final result = await _apiClient.post('/chats/$chatId/calls/join/');
    return result.map(
      (data) => CallTokenModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, void>> muteCallParticipant(
    String chatId,
    int userId,
    bool muted,
  ) async {
    final result = await _apiClient.post(
      '/chats/$chatId/calls/participants/$userId/mute/',
      data: {'muted': muted},
    );
    return result.map((_) {});
  }

  static String encodeEmojiPathSegment(String emoji) =>
      Uri.encodeComponent(emoji);

  @override
  Future<Either<Failure, void>> setReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    final encoded = encodeEmojiPathSegment(emoji);
    final result = await _apiClient.put(
      '/chats/$chatId/messages/$messageId/reactions/$encoded/',
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> removeReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    final encoded = encodeEmojiPathSegment(emoji);
    final result = await _apiClient.delete(
      '/chats/$chatId/messages/$messageId/reactions/$encoded/',
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> replaceReactions(
    String chatId,
    String messageId,
    List<String> emojis,
  ) async {
    final result = await _apiClient.put(
      '/chats/$chatId/messages/$messageId/reactions/',
      data: {'reactions': emojis},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> clearReactions(
    String chatId,
    String messageId,
  ) async {
    final result = await _apiClient.delete(
      '/chats/$chatId/messages/$messageId/reactions/',
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, MessageReactionsModel>> fetchReactions(
    String chatId,
    String messageId, {
    String? emoji,
    int limit = 50,
    int? cursorUserId,
  }) async {
    final result = await _apiClient.get(
      '/chats/$chatId/messages/$messageId/reactions/',
      queryParameters: {
        'limit': limit,
        if (emoji?.isNotEmpty == true) 'emoji': emoji,
        ...?cursorUserId != null ? {'cursor_user_id': cursorUserId} : null,
      },
    );
    return result.map(
      (data) => MessageReactionsModel.fromJson(data as Map<String, dynamic>),
    );
  }
}

final chatRestDataSourceProvider = Provider<ChatRestDataSource>((ref) {
  return ChatRestDataSourceImpl(ref.watch(apiClientProvider));
});
