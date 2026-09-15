import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/entities/message_search_terms.dart';
import 'package:chatix/features/chat/domain/repositories/message_search_repository.dart';

/// Searches the messages this device has already loaded.
///
/// The fallback for a search that cannot reach `GET /chats/messages/search/`
/// at all. It says [MessageSearchSource.localCache], and the screen turns
/// that into a line telling the reader what was actually searched — a
/// fraction of the history, presented as such.
///
/// Matching follows the server's rules as closely as a client can: the query
/// is cut into terms, every term has to appear, and the last one matches by
/// prefix (api-docs §5.4.1). It is not the same index, but it does not
/// disagree about what counts as a hit.
class LocalMessageSearchRepository implements MessageSearchRepository {
  const LocalMessageSearchRepository(this._store);

  final MessageCacheStore _store;

  @override
  Future<Either<Failure, MessageSearchResult>> search(
    String query, {
    String? chatId,
    int limit = 30,
    String? lastMessageId,
    RequestCancellation? cancellation,
  }) async {
    final terms = MessageSearchTerms.of(query);
    if (terms.isEmpty) {
      return const Right(
        MessageSearchResult(hits: [], source: MessageSearchSource.localCache),
      );
    }

    final pool = chatId == null ? _store.all() : _store.messagesOf(chatId);

    final matched = <MessageEntity>[];
    for (final message in pool) {
      final content = message.content;
      if (content == null || content.isEmpty) continue;
      if (!_matches(content, terms)) continue;
      matched.add(message);
    }

    // Newest first, the order the server answers in.
    matched.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // A cursor over a cache that changes under us would promise more than it
    // can keep, so a local page is the only page.
    final hits = <MessageSearchHit>[];
    for (final message in matched) {
      if (hits.length >= limit) break;
      final hit = MessageSearchHit.of(message, query);
      if (hit != null) hits.add(hit);
    }

    return Right(
      MessageSearchResult(
        hits: hits,
        source: MessageSearchSource.localCache,
      ),
    );
  }

  /// Every term present, the last one as a prefix — which for a substring
  /// check is the same test, since a prefix of a word is a substring of it.
  static bool _matches(String content, MessageSearchTerms terms) {
    final haystack = content.toLowerCase();

    for (final term in terms.terms) {
      if (!haystack.contains(term)) return false;
    }
    return true;
  }
}
