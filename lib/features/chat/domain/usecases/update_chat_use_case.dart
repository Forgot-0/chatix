import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:fpdart/fpdart.dart';

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
    ChatReactionsMode? reactionsMode,
    List<String>? allowedReactions,
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
        permissions == null &&
        reactionsMode == null &&
        allowedReactions == null;
    if (noChanges) {
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
      return _fail(
        'Slow mode must be between 0 and '
        '${CreateChatUseCase.maxSlowModeSeconds} seconds',
      );
    }

    if (reactionsMode == ChatReactionsMode.some &&
        (allowedReactions == null || allowedReactions.isEmpty)) {
      return _fail('Pick at least one emoji to allow');
    }

    return _repository.updateChat(
      chatId,
      name: name?.trim(),
      description: description?.trim(),
      isPublic: isPublic,
      adminOnly: adminOnly,
      slowModeSeconds: slowModeSeconds,
      permissions: permissions,
      reactionsMode: reactionsMode,
      allowedReactions: allowedReactions,
    );
  }

  Future<Either<Failure, ChatEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
