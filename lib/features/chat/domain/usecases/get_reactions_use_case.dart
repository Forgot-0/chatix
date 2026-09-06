import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

class GetReactionsUseCase {
  static const int maxLimit = 100;

  static const int defaultLimit = 50;

  final ChatRepository _repository;

  GetReactionsUseCase(this._repository);

  Future<Either<Failure, MessageReactionsEntity>> execute(
    String chatId,
    String messageId,
  ) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');

    return _repository.getReactions(chatId, messageId);
  }

  Future<Either<Failure, MessageReactionsEntity>> executeUsers(
    String chatId,
    String messageId, {
    required String emoji,
    int limit = defaultLimit,
    int? cursorUserId,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');
    if (emoji.isEmpty || emoji.trim().isEmpty) {
      return _fail('A reaction is required to list who reacted');
    }
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    if (cursorUserId != null && cursorUserId < 1) {
      return _fail('Invalid pagination cursor');
    }

    return _repository.getReactions(
      chatId,
      messageId,
      emoji: emoji,
      limit: limit,
      cursorUserId: cursorUserId,
    );
  }

  Future<Either<Failure, MessageReactionsEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
