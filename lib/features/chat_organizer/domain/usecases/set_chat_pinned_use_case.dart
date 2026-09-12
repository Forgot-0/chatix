import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_failures.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';

/// Pins a chat to the top of the list, or lets it go.
///
/// Refuses past [OrganizerLimits.pinnedChats] rather than quietly dropping
/// the oldest pin: which one to lose is the reader's call, not ours.
class SetChatPinnedUseCase {
  const SetChatPinnedUseCase(this._repository);

  final ChatOrganizerRepository _repository;

  Future<Either<Failure, ChatOrganizerData>> execute(
    ChatOrganizerData data, {
    required String chatId,
    required bool pinned,
  }) async {
    if (data.isPinned(chatId) == pinned) return right(data);

    if (pinned && !data.canPinMore) {
      return left(const PinLimitFailure());
    }

    final next = pinned
        ? <String>{...data.pinnedChatIds, chatId}
        : data.pinnedChatIds.where((id) => id != chatId).toSet();

    final saved = await _repository.savePinned(next);
    return saved.map((_) => data.copyWith(pinnedChatIds: next));
  }
}
