import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:fpdart/fpdart.dart';

/// `PATCH /chats/{chat_id}/` 🔒 4/5min (api-docs §6.2).
///
/// ⚠️ A genuine `PATCH`: omitted fields keep their current value, so callers
/// pass only what changed — unlike `PUT /profiles/{id}/` (§4.4), where every
/// field must be resent or it is wiped. Requires `chat:update`/
/// `settings:update` (§9.1).
class UpdateChatUseCase {
  final ChatRepository _repository;

  UpdateChatUseCase(this._repository);

  Future<Either<Failure, ChatEntity>> execute(
    String chatId, {
    String? name,
    String? description,
    bool? isPublic,
    bool? adminOnly,
    int? slowModeSeconds,
    Map<String, bool>? permissions,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }

    final noChanges =
        name == null &&
        description == null &&
        isPublic == null &&
        adminOnly == null &&
        slowModeSeconds == null &&
        permissions == null;
    if (noChanges) {
      // Would be a no-op PATCH that still costs one of only 4 calls per
      // 5 minutes.
      return _fail('Nothing to update');
    }

    if (name != null && name.trim().isEmpty) {
      return _fail('Chat name cannot be empty');
    }
    if (name != null && name.length > CreateChatUseCase.maxNameLength) {
      return _fail(
        'Chat name must be ${CreateChatUseCase.maxNameLength} characters or fewer',
      );
    }
    if (description != null &&
        description.length > CreateChatUseCase.maxDescriptionLength) {
      return _fail(
        'Chat description must be '
        '${CreateChatUseCase.maxDescriptionLength} characters or fewer',
      );
    }
    if (slowModeSeconds != null &&
        (slowModeSeconds < 0 ||
            slowModeSeconds > CreateChatUseCase.maxSlowModeSeconds)) {
      // `400 SLOW_MODE_OUT_OF_RANGE` server-side (api-docs §6.4).
      return _fail(
        'Slow mode must be between 0 and '
        '${CreateChatUseCase.maxSlowModeSeconds} seconds',
      );
    }

    return _repository.updateChat(
      chatId,
      name: name?.trim(),
      description: description?.trim(),
      isPublic: isPublic,
      adminOnly: adminOnly,
      slowModeSeconds: slowModeSeconds,
      permissions: permissions,
    );
  }

  Future<Either<Failure, ChatEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
