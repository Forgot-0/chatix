import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';

/// Where message hits come from.
///
/// One interface with two futures behind it. Today the only implementation
/// reads the messages this device has loaded; when the backend grows a search
/// endpoint, a second implementation calls it and
/// `messageSearchRepositoryProvider` picks that one instead. Nothing above
/// this line changes, which is why [MessageSearchSource] travels with the
/// result rather than being assumed by the screen.
abstract interface class MessageSearchRepository {
  /// What this implementation can honestly claim to have searched.
  MessageSearchSource get source;

  /// Messages matching [query], newest first.
  ///
  /// [chatId] narrows the search to one conversation, which is what the
  /// in-chat search uses. [cancellation] is here for the implementation that
  /// makes a request; the local one ignores it.
  Future<Either<Failure, MessageSearchResult>> search(
    String query, {
    String? chatId,
    int limit,
    RequestCancellation? cancellation,
  });
}
