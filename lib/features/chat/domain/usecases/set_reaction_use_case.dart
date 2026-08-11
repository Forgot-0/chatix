import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

/// `PUT /chats/{chat_id}/messages/{message_id}/reactions/{emoji}/` 🔒 10/sec
/// → 204 (api-docs §6.7.1).
///
/// ⚠️ **Sets** the caller's one reaction, it does not add to a set: the
/// backend holds `UniqueConstraint(message_id, user_id)` (§6.7.2). Reacting
/// with a second emoji therefore *replaces* the first — the old counter drops,
/// the new one rises, and two `reaction_updated` events come back. Re-sending
/// the emoji already set is a server-side no-op (still 204), so callers that
/// want "tap again to remove" must use [RemoveReactionUseCase] instead of
/// relying on this being a toggle.
class SetReactionUseCase {
  /// `MAX_REACRTION_LENGTH` (api-docs §6.7.4 — the typo is the backend's).
  static const int maxEmojiLength = 32;

  final ChatRepository _repository;

  SetReactionUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    String messageId,
    String emoji,
  ) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');

    // Mirrors the server's `INVALID_REACTION` rule (§6.7.4): empty, blank,
    // longer than 32, or containing a NUL. Checked here because the endpoint
    // is rate-limited to 10/sec and a rejected reaction is a wasted slot.
    //
    // ⚠️ NOT trimmed before sending: the emoji is a path parameter and an
    // identity — the string sent must be byte-identical to the one that comes
    // back in summaries and in the WS event, or the chip would never match.
    if (emoji.isEmpty || emoji.trim().isEmpty) {
      return _fail('Pick a reaction');
    }
    if (emoji.length > maxEmojiLength) {
      return _fail('A reaction can be at most $maxEmojiLength characters long');
    }
    if (emoji.contains('\u0000')) {
      return _fail('That reaction contains an unsupported character');
    }

    return _repository.setReaction(chatId, messageId, emoji);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
