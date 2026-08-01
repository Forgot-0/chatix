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
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// Talks to `/chats/*` (api-docs §6) over **REST** via [ApiClient], which
/// already maps Dio responses/errors into `Either<Failure, dynamic>`.
///
/// This sits beside `ChatRemoteDataSource`, which owns the WebSocket
/// connection (api-docs §7) — deliberately two classes: the socket is
/// long-lived, stateful and reconnecting, while these are plain
/// request/response calls, and mixing them would make either half impossible
/// to test or fake on its own.
///
/// This layer's only job is building the right path/query/body and parsing
/// JSON into models. No Model→Entity mapping (that's `ChatRepositoryImpl`) and
/// no business rules (that's `domain/usecases/*`) — with one deliberate
/// exception documented on [createChat], where an invalid request is cheaper
/// to reject here than to round-trip.
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

  Future<Either<Failure, AttachmentDownloadUrlModel>> fetchAttachmentDownloadUrl(
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
}

class ChatRestDataSourceImpl implements ChatRestDataSource {
  final ApiClient _apiClient;
  final Uuid _uuid;

  ChatRestDataSourceImpl(this._apiClient, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  // ─────────────────────────── Chats (§6.2) ───────────────────────────

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
        // Cursor params are omitted entirely on the first page — sending
        // explicit nulls makes the backend treat them as provided-but-empty.
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
    // ⚠️ Client-side guard, normally a use-case concern (api-docs §6.2): a
    // direct chat must carry EXACTLY one member id — the other participant,
    // since the caller is added implicitly. The server answers anything else
    // with `400 MEMBER_LIMIT_EXCEEDED`, whose name is actively misleading for
    // the "I sent zero ids" case, so it is rejected here with a message a
    // human can act on. `CreateChatUseCase` performs the same check earlier
    // with fuller UX context; this one is the last line of defence for
    // callers that reach the repository directly.
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
  }) async {
    // ⚠️ api-docs §6.2: PATCH, not PUT. Only the keys present in the body are
    // touched, so absent named parameters are left out rather than sent as
    // null (null on the wire would be read as "no change" anyway, but keeping
    // the body minimal makes the intent unambiguous).
    final result = await _apiClient.patch(
      '/chats/$chatId/',
      data: {
        'name': ?name,
        'description': ?description,
        'is_public': ?isPublic,
        'admin_only': ?adminOnly,
        'slow_mode_seconds': ?slowModeSeconds,
        'permissions': ?permissions,
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

  // ────────────────────────── Members (§6.3) ──────────────────────────

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
        // `BanMemberRequest {reason?, banned_to?}` (api-docs §6.3). Omitted
        // entirely when null, which the backend reads as a permanent ban —
        // sending an explicit null would be rejected by the datetime
        // validator rather than treated as "no expiry".
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

  // ───────────────────────── Messages (§6.4) ──────────────────────────

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
    // api-docs §6.4: `Idempotency-Key` is optional on the wire but always
    // sent here — a v4 UUID generated per call when the caller didn't supply
    // one. Replaying the same key within 24 h returns the cached first
    // result instead of a duplicate message, which is what makes the
    // "offline → tap send again on reconnect" retry safe. Callers that
    // implement such a retry MUST hold on to their key and pass it back in
    // (see `SendMessageUseCase`); a key minted fresh per attempt provides no
    // protection at all, which is exactly why generating it here is only a
    // fallback and not the whole story.
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
  }) async {
    // ⚠️ The DESTINATION chat is the one in the path (api-docs §6.4); the
    // source pair travels in the body.
    final result = await _apiClient.post(
      '/chats/$targetChatId/messages/forward/',
      data: {
        'source_chat_id': sourceChatId,
        'source_message_id': sourceMessageId,
        'comment': ?comment,
      },
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

  // ──────────────────────── Attachments (§6.5) ────────────────────────

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
              },
            )
            .toList(),
      },
    );
    // ⚠️ api-docs §6.5: the 201 body is a BARE ARRAY of tickets, not an
    // object with a `uploads`/`items` key like every other list in the API.
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
    // Returns 202 with an empty body — queued, not validated (api-docs §6.5).
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

  // ─────────────────────────── Calls (§6.6) ───────────────────────────

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
}

final chatRestDataSourceProvider = Provider<ChatRestDataSource>((ref) {
  return ChatRestDataSourceImpl(ref.watch(apiClientProvider));
});
