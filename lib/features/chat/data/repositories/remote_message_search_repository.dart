import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/chat/data/models/message_search_model.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/repositories/message_search_repository.dart';

/// Searches the history the server can see: every chat the caller is still
/// a member of, whether or not this device has ever loaded it
/// (`GET /chats/messages/search/`, api-docs §5.4.1).
class RemoteMessageSearchRepository implements MessageSearchRepository {
  const RemoteMessageSearchRepository(this._remote);

  final ChatRestDataSource _remote;

  @override
  Future<Either<Failure, MessageSearchResult>> search(
    String query, {
    String? chatId,
    int limit = 30,
    String? lastMessageId,
    RequestCancellation? cancellation,
  }) async {
    final result = await _remote.searchMessages(
      query,
      chatId: chatId,
      limit: limit,
      lastMessageId: lastMessageId,
      cancellation: cancellation,
    );

    return result.map((model) => model.toEntity(query));
  }
}

/// The server search, with the device's own messages behind it.
///
/// Only for a request that could not be made — no network, or one that timed
/// out. Anything the server did answer, including an empty page, is the
/// answer: falling back on a `422` or a rate limit would hide a real problem
/// behind a worse result.
class OfflineFallbackMessageSearchRepository
    implements MessageSearchRepository {
  const OfflineFallbackMessageSearchRepository({
    required MessageSearchRepository remote,
    required MessageSearchRepository local,
  }) : _remote = remote,
       _local = local;

  final MessageSearchRepository _remote;
  final MessageSearchRepository _local;

  @override
  Future<Either<Failure, MessageSearchResult>> search(
    String query, {
    String? chatId,
    int limit = 30,
    String? lastMessageId,
    RequestCancellation? cancellation,
  }) async {
    final result = await _remote.search(
      query,
      chatId: chatId,
      limit: limit,
      lastMessageId: lastMessageId,
      cancellation: cancellation,
    );

    final failure = result.getLeft().toNullable();
    if (failure == null || !_isUnreachable(failure)) return result;

    Logger.debug(
      'MessageSearch: server unreachable, searching what is on the device',
    );

    // A cursor from the server means nothing to the cache; a fallback is
    // always the first page of what is here.
    return _local.search(query, chatId: chatId, limit: limit);
  }

  static bool _isUnreachable(Failure failure) =>
      failure is NetworkFailure || failure is TimeoutFailure;
}
