import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/repositories/message_search_repository.dart';

class SearchMessagesUseCase {
  const SearchMessagesUseCase(this._repository);

  static const int defaultLimit = 100;
  static const int maxLimit = 500;

  final MessageSearchRepository _repository;

  /// What the results can claim to cover, which the screen has to say out
  /// loud while it is [MessageSearchSource.localCache].
  MessageSearchSource get source => _repository.source;

  Future<Either<Failure, MessageSearchResult>> execute(
    String query, {
    String? chatId,
    int limit = defaultLimit,
    RequestCancellation? cancellation,
  }) {
    final needle = query.trim();
    if (needle.isEmpty) {
      // Not an error: an empty box has no results, it has a history list.
      return Future.value(
        Right(MessageSearchResult(hits: const [], source: _repository.source)),
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
      cancellation: cancellation,
    );
  }
}
