import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';

/// Where message hits come from.
///
/// Two implementations: `GET /chats/messages/search/` (api-docs §5.4.1), and
/// the messages this device has already loaded, for when that request cannot
/// be made. The result says which one answered, so the screen can be honest
/// about what was searched without knowing how it was wired.
abstract interface class MessageSearchRepository {
  /// Messages matching [query], newest first.
  ///
  /// [chatId] narrows the search to one conversation. [lastMessageId] is the
  /// keyset cursor from the previous page.
  Future<Either<Failure, MessageSearchResult>> search(
    String query, {
    String? chatId,
    int limit,
    String? lastMessageId,
    RequestCancellation? cancellation,
  });
}
