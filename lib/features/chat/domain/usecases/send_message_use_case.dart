import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

/// `POST /chats/{chat_id}/messages/` 🔒 (api-docs §6.4).
///
/// ### Idempotency contract
///
/// The `Idempotency-Key` header is what keeps "the send failed, let me tap it
/// again" from posting the message twice: within 24 h the backend answers a
/// repeated key with the cached first result instead of creating a second
/// message (api-docs §6.4).
///
/// That only works if the key is **stable across retries of the same logical
/// send**, which the caller — not this use case — is the one who knows about.
/// Hence the split:
///
/// * [newIdempotencyKey] mints a v4 UUID. Call it **once**, when the user
///   presses send, and keep it with the pending message.
/// * [execute] takes that key back as [idempotencyKey] on every attempt.
///
/// Omitting the key still works (the data source generates one per request),
/// but then a retry is a *different* key and duplicates are possible again —
/// so [idempotencyKey] is effectively required for any code path that can
/// retry. `ChatMessagesController.sendMessage` follows exactly this pattern.
///
/// A retry that overlaps the still-in-flight original gets
/// `409 IDEMPOTENCY_CONFLICT`, which means "the first attempt is still being
/// processed" — the right response is to wait and re-read the message list,
/// not to send again.
class SendMessageUseCase {
  /// `SendMessageRequest.content` cap (api-docs §6.4).
  static const int maxContentLength = 4096;

  final ChatRepository _repository;

  SendMessageUseCase(this._repository);

  Future<Either<Failure, MessageEntity>> execute(
    String chatId, {
    String? content,
    String? replyToId,
    MessageType? messageType,
    List<String>? uploadTokens,
    String? idempotencyKey,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }

    final trimmed = content?.trim();
    final hasText = trimmed != null && trimmed.isNotEmpty;
    final hasAttachments = uploadTokens != null && uploadTokens.isNotEmpty;

    // The server rejects a message with neither text nor attachments
    // (`400 INVALID_MESSAGE`); catching it here keeps an accidental empty
    // send from costing a round-trip and burning rate-limit budget
    // (10 msg/sec).
    if (!hasText && !hasAttachments) {
      return _fail('Cannot send an empty message');
    }

    if (trimmed != null && trimmed.length > maxContentLength) {
      return _fail(
        'Message is too long: ${trimmed.length} characters, '
        'the limit is $maxContentLength',
      );
    }

    // Sending `reply_to_id` implies a reply. The backend derives the type
    // itself, but being explicit keeps the returned `MessageDTO.type`
    // consistent with what the UI already rendered optimistically.
    final resolvedType =
        messageType ?? (replyToId != null ? MessageType.reply : null);

    return _repository.sendMessage(
      chatId,
      // Whitespace-only content becomes null rather than "   ": for an
      // attachment-only message that is the difference between "no caption"
      // and "a caption made of spaces".
      content: hasText ? trimmed : null,
      replyToId: replyToId,
      messageType: resolvedType,
      uploadTokens: uploadTokens,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Either<Failure, MessageEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
