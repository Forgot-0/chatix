import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';

/// Moves a chat into the archive, or takes it back out.
///
/// Archiving releases the pin: the pinned zone is what you want in front of
/// you, and something you just put away is not that.
class SetChatArchivedUseCase {
  const SetChatArchivedUseCase(this._repository);

  final ChatOrganizerRepository _repository;

  Future<Either<Failure, ChatOrganizerData>> execute(
    ChatOrganizerData data, {
    required String chatId,
    required bool archived,
  }) async {
    if (data.isArchived(chatId) == archived) return right(data);

    final nextArchived = archived
        ? <String>{...data.archivedChatIds, chatId}
        : data.archivedChatIds.where((id) => id != chatId).toSet();

    final saved = await _repository.saveArchived(nextArchived);
    if (saved.isLeft()) {
      return saved.map((_) => data);
    }

    var next = data.copyWith(archivedChatIds: nextArchived);

    if (archived && data.isPinned(chatId)) {
      final nextPinned = data.pinnedChatIds
          .where((id) => id != chatId)
          .toSet();
      final pinsSaved = await _repository.savePinned(nextPinned);
      if (pinsSaved.isRight()) {
        next = next.copyWith(pinnedChatIds: nextPinned);
      }
    }

    return right(next);
  }
}
