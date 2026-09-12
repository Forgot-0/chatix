import 'package:equatable/equatable.dart';

import 'package:chatix/core/utils/text_match.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// Where message hits came from.
///
/// There is no message search in the API (api-docs §5.4 lists every message
/// route, none of them a search), so today this is always
/// [MessageSearchSource.localCache] and the screen says so out loud. The day
/// a server search exists, the repository behind it reports
/// [MessageSearchSource.server] and the notice goes away on its own.
enum MessageSearchSource {
  /// Messages this device has already loaded.
  localCache,

  /// A real search across the whole history, run by the backend.
  server,
}

/// One message that matched, with the piece of it worth showing.
class MessageSearchHit extends Equatable {
  const MessageSearchHit({
    required this.message,
    required this.snippet,
    required this.matchStart,
    required this.matchLength,
  });

  /// Builds a hit, or null when [query] is not in the message after all.
  static MessageSearchHit? of(MessageEntity message, String query) {
    final content = message.content;
    if (content == null || content.isEmpty) return null;

    final snippet = snippetAround(content, query);
    if (!snippet.hasMatch) return null;

    return MessageSearchHit(
      message: message,
      snippet: snippet.text,
      matchStart: snippet.matchStart,
      matchLength: snippet.matchLength,
    );
  }

  final MessageEntity message;

  /// The message trimmed to a window around the match.
  final String snippet;

  /// Where the match sits inside [snippet].
  final int matchStart;

  final int matchLength;

  String get chatId => message.chatId;

  int get seq => message.seq;

  @override
  List<Object?> get props => [message, snippet, matchStart, matchLength];
}

class MessageSearchResult extends Equatable {
  const MessageSearchResult({
    required this.hits,
    required this.source,
    this.isCapped = false,
  });

  static const MessageSearchResult empty = MessageSearchResult(
    hits: [],
    source: MessageSearchSource.localCache,
  );

  final List<MessageSearchHit> hits;

  final MessageSearchSource source;

  /// There were more matches than the search was willing to return. Only the
  /// local search sets it: the cap is ours, not the server's.
  final bool isCapped;

  bool get isEmpty => hits.isEmpty;

  @override
  List<Object?> get props => [hits, source, isCapped];
}
