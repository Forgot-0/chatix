import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/repositories/message_search_repository.dart';

class SearchMessagesUseCase {
  const SearchMessagesUseCase(this._repository);

  /// The server's own bounds (api-docs §5.4.1): shorter or longer than this
  /// is a `422`, so the client does not ask.
  static const int minQueryLength = 2;
  static const int maxQueryLength = 150;

  static const int defaultLimit = 30;
  static const int maxLimit = 50;

  final MessageSearchRepository _repository;

  Future<Either<Failure, MessageSearchResult>> execute(
    String query, {
    String? chatId,
    int limit = defaultLimit,
    String? lastMessageId,
    RequestCancellation? cancellation,
  }) {
    final needle = query.trim();

    // Not an error: a box with one letter in it has no results, it has a
    // hint telling the reader to keep typing.
    if (needle.length < minQueryLength) {
      return Future.value(const Right(MessageSearchResult.empty));
    }

    if (needle.length > maxQueryLength) {
      return Future.value(
        Left(
          InputFailure(
            message: 'A search can be at most $maxQueryLength characters',
          ),
        ),
      );
    }

    if (limit < 1 || limit > maxLimit) {
      return Future.value(
        Left(InputFailure(message: 'Limit must be between 1 and $maxLimit')),
      );
    }

    return _repository.search(
      needle,
      chatId: chatId,
      limit: limit,
      lastMessageId: lastMessageId,
      cancellation: cancellation,
    );
  }
}
