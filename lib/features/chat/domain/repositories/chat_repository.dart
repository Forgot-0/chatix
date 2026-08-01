import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// Chats REST surface (api-docs §6). Everything here requires auth.
///
/// This is the **REST half** of the chat feature only. Live message delivery,
/// typing indicators, presence pushes and `attachment_success` arrive over the
/// WebSocket protocol of api-docs §7, which is a separate concern layered on
/// top of this same repository later — nothing in this interface streams.
///
/// All methods return `Either<Failure, T>`; error codes surface as
/// [ApiFailure.code] (api-docs §2.7), so callers can branch on e.g.
/// `DIRECT_CHAT_EXISTS` or `SLOW_MODE_LIMIT` instead of parsing messages.
abstract class ChatRepository {
  // ─────────────────────────── Chats (§6.2) ───────────────────────────

  /// `GET /chats/` — cursor-paginated (api-docs §1.6, §6.2).
  ///
  /// For the first page pass neither cursor. For each subsequent page pass
  /// **both** [lastChatId] and [lastActivityAt] straight from the previous
  /// [ChatsPage] (`nextChatId`/`nextDate`) — the pair is the cursor, and
  /// `last_activity_at` alone is not unique.
  Future<Either<Failure, ChatsPage>> getChats({
    int limit = 50,
    String? lastChatId,
    DateTime? lastActivityAt,
  });

  /// `POST /chats/` 4/5min (api-docs §6.2). Returns the created `ChatDTO`.
  ///
  /// ⚠️ For [chatType] `direct`, [memberIds] must hold **exactly one** id
  /// (the other participant; the caller is added implicitly). The
  /// implementation rejects anything else locally before the request goes
  /// out, instead of waiting for `400 MEMBER_LIMIT_EXCEEDED`.
  ///
  /// A repeat direct chat fails with `409 DIRECT_CHAT_EXISTS`, whose
  /// `detail.chat_id` already contains the existing chat's id — callers
  /// should open that chat rather than surfacing an error.
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

  /// `GET /chats/{chat_id}/` (api-docs §6.2) → `ChatDetaiDTO`: carries the
  /// full member list but **no** `unread_count`/`me`/`last_read`.
  Future<Either<Failure, ChatEntity>> getChat(String chatId);

  /// `PATCH /chats/{chat_id}/` 4/5min (api-docs §6.2).
  ///
  /// ⚠️ A real `PATCH`, not `PUT` (unlike `PUT /profiles/{id}/` in §4.4):
  /// omitted fields are left untouched server-side, so callers only send what
  /// changed. Passing `null` means "don't change" — there is no way to null a
  /// field back out through this endpoint.
  Future<Either<Failure, ChatEntity>> updateChat(
    String chatId, {
    String? name,
    String? description,
    bool? isPublic,
    bool? adminOnly,
    int? slowModeSeconds,
    Map<String, bool>? permissions,
  });

  /// `DELETE /chats/{chat_id}/` 4/5min → 204 (api-docs §6.2).
  /// Requires `chat:delete`, i.e. owner only (§9.1).
  Future<Either<Failure, void>> deleteChat(String chatId);

  /// `POST /chats/{chat_id}/join/` 10/5min → 204 (api-docs §6.2).
  /// Only meaningful for chats with `is_public == true`.
  Future<Either<Failure, void>> joinChat(String chatId);

  /// `POST /chats/{chat_id}/leave/` 4/5min → 204 (api-docs §6.2).
  Future<Either<Failure, void>> leaveChat(String chatId);

  // ────────────────────────── Members (§6.3) ──────────────────────────

  /// `GET /chats/{chat_id}/members/` — cursor-paginated (api-docs §6.3).
  ///
  /// [limit] may go up to 500 here (not 100 like the other lists).
  /// [includePresence] is what populates [MembersPage.presence]; it is off by
  /// default because it costs the backend an extra lookup per member.
  Future<Either<Failure, MembersPage>> getMembers(
    String chatId, {
    int limit = 50,
    int? cursorUserId,
    bool includePresence = false,
  });

  /// `POST /chats/{chat_id}/members/` 30/5min → 204 (api-docs §6.3).
  /// Requires `member:invite`. `409 ALREADY_CHAT_MEMBER` if they're in.
  Future<Either<Failure, void>> addMember(
    String chatId,
    int userId, {
    int roleId = 5,
  });

  /// `PATCH /chats/{chat_id}/members/{user_id}/role/` → 204 (api-docs §6.3).
  /// Requires `role:change`.
  Future<Either<Failure, void>> changeMemberRole(
    String chatId,
    int userId,
    int roleId,
  );

  /// `PATCH /chats/{chat_id}/members/{user_id}/ban/` → 204 (api-docs §6.3).
  /// Requires `member:ban`.
  ///
  /// [bannedTo] is the ban expiry; omit it for a permanent ban. ⚠️ It is
  /// serialised as `bannet_to` — a typo preserved verbatim in the backend
  /// schema (api-docs §6.3). The Dart parameter keeps the correct spelling;
  /// only the wire key is misspelled.
  Future<Either<Failure, void>> banMember(
    String chatId,
    int userId, {
    String? reason,
    DateTime? bannedTo,
  });

  /// `DELETE /chats/{chat_id}/members/{user_id}/` → 204 (api-docs §6.3).
  /// Requires `member:kick`. A kick is not a ban: the user may re-join a
  /// public chat afterwards.
  Future<Either<Failure, void>> kickMember(String chatId, int userId);

  // ───────────────────────── Messages (§6.4) ──────────────────────────

  /// `GET /chats/{chat_id}/messages/` — cursor-paginated, newest first
  /// (api-docs §6.4). [cursorMessageSeq] comes from
  /// [MessagesPage.nextCursor]; omit it for the newest page.
  Future<Either<Failure, MessagesPage>> getMessages(
    String chatId, {
    int limit = 30,
    int? cursorMessageSeq,
  });

  /// `GET /chats/{chat_id}/messages/context/` (api-docs §6.4) — the window of
  /// messages *around* [targetSeq], for "jump to message" (opening a reply's
  /// original, or a search hit). Unlike [getMessages] this returns messages
  /// both newer and older than the target.
  Future<Either<Failure, MessagesPage>> getMessagesContext(
    String chatId,
    int targetSeq, {
    int limit = 40,
  });

  /// `POST /chats/{chat_id}/messages/` 10/sec (api-docs §6.4) → the created
  /// `MessageDTO`.
  ///
  /// At least one of [content] or [uploadTokens] must be meaningful — an
  /// empty message is rejected (`400 INVALID_MESSAGE`). [content] is capped at
  /// 4096 characters.
  ///
  /// [idempotencyKey] goes out as the `Idempotency-Key` header. Replaying the
  /// same key within 24 h returns the *cached first result* instead of posting
  /// a duplicate, which is what makes "no network → user taps send again"
  /// safe. The implementation generates a v4 UUID when this is omitted, but
  /// callers that want retry protection must generate the key **once** and
  /// reuse it across attempts — a fresh key per attempt defeats the purpose.
  /// A retry that races the still-in-flight original yields
  /// `409 IDEMPOTENCY_CONFLICT`.
  ///
  /// [replyToId] makes this a reply; [messageType] defaults to `text`.
  Future<Either<Failure, MessageEntity>> sendMessage(
    String chatId, {
    String? content,
    String? replyToId,
    MessageType? messageType,
    List<String>? uploadTokens,
    String? idempotencyKey,
  });

  /// `GET /chats/{chat_id}/messages/{message_id}/` (api-docs §6.4). The way
  /// to resolve a WS `new_message`/`message_edited` event, which carries ids
  /// only (§7.4).
  Future<Either<Failure, MessageEntity>> getMessage(
    String chatId,
    String messageId,
  );

  /// `PATCH /chats/{chat_id}/messages/{message_id}/` (api-docs §6.4).
  /// [content] must be 1..4096 characters — editing to empty is not allowed.
  Future<Either<Failure, MessageEntity>> editMessage(
    String chatId,
    String messageId,
    String content,
  );

  /// `DELETE /chats/{chat_id}/messages/{message_id}/` → 204 (api-docs §6.4).
  /// Requires `message:delete` for other people's messages (§9.1).
  Future<Either<Failure, void>> deleteMessage(String chatId, String messageId);

  /// `POST /chats/{target_chat_id}/messages/forward/` 10/sec (api-docs §6.4).
  ///
  /// ⚠️ The chat in the **path is the destination** ([targetChatId]); the
  /// source lives in the body. Getting this backwards silently posts into the
  /// wrong conversation, so the parameters are all named.
  Future<Either<Failure, MessageEntity>> forwardMessage({
    required String sourceChatId,
    required String sourceMessageId,
    required String targetChatId,
    String? comment,
  });

  /// `POST /chats/{chat_id}/messages/read/` → 204 (api-docs §6.4).
  /// [messageSeq] is a `seq`, **not** a message id.
  Future<Either<Failure, void>> markRead(String chatId, int messageSeq);

  // ──────────────────────── Attachments (§6.5) ────────────────────────

  /// Step 1 — `POST /chats/{chat_id}/attachments/upload-requests/`
  /// (api-docs §6.5) → one ticket per requested file, as a **bare array**.
  ///
  /// This only reserves upload slots; the bytes are then PUT directly to each
  /// ticket's `uploadUrl` (step 2) and confirmed (step 3). Prefer
  /// `UploadChatAttachmentUseCase`, which drives all three steps and enforces
  /// the size/count/MIME limits, over calling these one by one.
  Future<Either<Failure, List<AttachmentUploadTicketEntity>>>
  requestAttachmentUpload(
    String chatId,
    List<AttachmentUploadRequestEntity> uploads,
  );

  /// Step 3 — `POST /chats/{chat_id}/attachments/upload-requests/confirm/`
  /// → `202 Accepted`, empty body (api-docs §6.5).
  ///
  /// Fire-and-forget: the 202 means "queued", not "validated". Per api-docs
  /// §6.5 the caller may proceed to `sendMessage` with these same
  /// [uploadTokens] immediately — the attachments simply arrive with
  /// `attachment_status: pending` and flip to `success` once the backend has
  /// probed the files (announced by the WS `attachment_success` event, §7.4).
  /// There is no WS event for the failure case, so a client that must be sure
  /// re-reads the message afterwards.
  Future<Either<Failure, void>> confirmAttachmentUpload(
    String chatId,
    List<String> uploadTokens,
  );

  /// `GET /chats/{chat_id}/messages/{message_id}/attachments/{attachment_id}/
  /// download-url/` (api-docs §6.5). The URL expires in 300 s — request it at
  /// the moment of use, don't cache it with the message.
  Future<Either<Failure, AttachmentDownloadUrlEntity>>
  getAttachmentDownloadUrl(
    String chatId,
    String messageId,
    String attachmentId,
  );

  // ─────────────────────────── Calls (§6.6) ───────────────────────────

  /// `POST /chats/{chat_id}/calls/join/` 10/5min → `JoinTokenDTO`
  /// (api-docs §6.6). Requires `call:join`. `404 NO_ACTIVE_CALL` /
  /// `409 ACTIVE_CALL_EXISTS` / `502 LIVEKIT_ERROR` are the interesting
  /// failures.
  Future<Either<Failure, CallTokenEntity>> joinCall(String chatId);

  /// `POST /chats/{chat_id}/calls/participants/{user_id}/mute/` 4/5min → 204
  /// (api-docs §6.6). Requires `call:mute_member`.
  Future<Either<Failure, void>> muteCallParticipant(
    String chatId,
    int userId,
    bool muted,
  );
}
