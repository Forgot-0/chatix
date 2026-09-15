import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

/// Pinning, archiving and silencing a chat for yourself.
///
/// One endpoint behind all of it — `PATCH /chats/{chat_id}/state/` — and one
/// method per thing a person can actually ask for, so no caller has to
/// remember that "unpin" is `pinned: false` while "unmute" is a field sent as
/// null (api-docs §5.2).
class UpdateChatStateUseCase {
  const UpdateChatStateUseCase(this._repository);

  /// What the server allows, and what the client refuses to try past.
  static const int pinnedLimit = 5;

  final ChatRepository _repository;

  Future<Either<Failure, ChatStateEntity>> setPinned(
    String chatId, {
    required bool pinned,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    return _repository.updateChatState(chatId, pinned: pinned);
  }

  Future<Either<Failure, ChatStateEntity>> setArchived(
    String chatId, {
    required bool archived,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    return _repository.updateChatState(chatId, archived: archived);
  }

  /// Silences the chat until [until], or forever.
  ///
  /// "Forever" has no flag of its own: the field holds a date, so the client
  /// sends one far enough out that nobody reaches it.
  Future<Either<Failure, ChatStateEntity>> mute(
    String chatId, {
    DateTime? until,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');

    final deadline = until ?? _forever;
    if (!deadline.isAfter(DateTime.now())) {
      return _fail('A mute has to end in the future');
    }

    return _repository.updateChatState(
      chatId,
      notificationsMutedUntil: deadline,
    );
  }

  Future<Either<Failure, ChatStateEntity>> unmute(String chatId) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    return _repository.updateChatState(
      chatId,
      clearNotificationsMutedUntil: true,
    );
  }

  /// Saves what was typed and never sent, or clears it.
  Future<Either<Failure, ChatStateEntity>> setDraft(
    String chatId,
    String? draft,
  ) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');

    final text = draft?.trim();
    if (text == null || text.isEmpty) {
      return _repository.updateChatState(chatId, clearDraft: true);
    }
    if (text.length > maxDraftLength) {
      return _fail('A draft can be at most $maxDraftLength characters');
    }

    return _repository.updateChatState(chatId, draft: text);
  }

  static const int maxDraftLength = 4096;

  /// Far enough away to mean "until I say otherwise", near enough to be a
  /// date the server will store.
  static DateTime get _forever => DateTime.utc(2999, 12, 31);

  Future<Either<Failure, ChatStateEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
