import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/core/utils/text_match.dart';
import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/repositories/message_search_repository.dart';

/// Searches the messages this device has already loaded.
///
/// Not a stand-in for a server search and not pretending to be one: it says
/// [MessageSearchSource.localCache], and the screen turns that into a line
/// telling the reader exactly what was searched. When the API grows a real
/// endpoint, this class stays for offline use and a remote sibling takes over
/// the provider.
class LocalMessageSearchRepository implements MessageSearchRepository {
  const LocalMessageSearchRepository(this._store);

  final MessageCacheStore _store;

  @override
  MessageSearchSource get source => MessageSearchSource.localCache;

  @override
  Future<Either<Failure, MessageSearchResult>> search(
    String query, {
    String? chatId,
    int limit = 100,
    RequestCancellation? cancellation,
  }) async {
    final needle = query.trim();
    if (needle.isEmpty) {
      return const Right(MessageSearchResult.empty);
    }

    final pool = chatId == null ? _store.all() : _store.messagesOf(chatId);

    final matched = <MessageEntity>[];
    for (final message in pool) {
      final content = message.content;
      if (content == null || content.isEmpty) continue;
      if (!containsIgnoreCase(content, needle)) continue;
      matched.add(message);
    }

    // Newest first, and never two rows for one message: a message can sit in
    // the cache under one chat only, but the pool is concatenated per chat.
    matched.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final hits = <MessageSearchHit>[];
    for (final message in matched) {
      if (hits.length >= limit) break;
      final hit = MessageSearchHit.of(message, needle);
      if (hit != null) hits.add(hit);
    }

    return Right(
      MessageSearchResult(
        hits: hits,
        source: source,
        isCapped: matched.length > hits.length,
      ),
    );
  }
}
