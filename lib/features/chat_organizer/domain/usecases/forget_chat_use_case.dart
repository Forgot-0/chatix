import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';

/// Drops every trace of a chat that is gone — deleted, or left.
///
/// Folders are rules, so they need no cleaning: a chat that no longer exists
/// stops matching on its own.
class ForgetChatUseCase {
  const ForgetChatUseCase(this._repository);

  final ChatOrganizerRepository _repository;

  Future<Either<Failure, ChatOrganizerData>> execute(
    ChatOrganizerData data,
    String chatId,
  ) async {
    if (!data.isPinned(chatId) && !data.isArchived(chatId)) return right(data);

    var next = data;

    if (data.isPinned(chatId)) {
      final pinned = data.pinnedChatIds.where((id) => id != chatId).toSet();
      final saved = await _repository.savePinned(pinned);
      if (saved.isLeft()) return saved.map((_) => data);
      next = next.copyWith(pinnedChatIds: pinned);
    }

    if (data.isArchived(chatId)) {
      final archived = data.archivedChatIds.where((id) => id != chatId).toSet();
      final saved = await _repository.saveArchived(archived);
      if (saved.isLeft()) return saved.map((_) => next);
      next = next.copyWith(archivedChatIds: archived);
    }

    return right(next);
  }
}
