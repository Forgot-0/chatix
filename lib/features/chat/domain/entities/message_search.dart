import 'package:equatable/equatable.dart';

import 'package:chatix/core/utils/text_match.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_search_terms.dart';

/// Where message hits came from.
///
/// `GET /chats/messages/search/` searches the whole history the caller can
/// see (api-docs §5.4.1). The local cache is the fallback for when that
/// request cannot be made at all, and the screen says so when it is used —
/// a search that quietly covered a fraction of the history would be worse
/// than one that admits it.
enum MessageSearchSource {
  /// Messages this device has already loaded.
  localCache,

  /// A real search across the whole history, run by the backend.
  server,
}

/// Just enough of a chat to draw a result row for a message in it.
///
/// The server sends this with every hit, because a match can come from a
/// chat the list has never loaded.
class MessageSearchChat extends Equatable {
  const MessageSearchChat({
    required this.id,
    required this.type,
    required this.name,
    this.avatarUrl,
    this.avatarS3Key,
  });

  final String id;
  final ChatType type;
  final String? name;

  /// Presigned, 300 seconds (api-docs §5.4.1) — cache the file by
  /// [avatarS3Key], never by this.
  final String? avatarUrl;

  final String? avatarS3Key;

  @override
  List<Object?> get props => [id, type, name, avatarUrl, avatarS3Key];
}

/// One message that matched, with the piece of it worth showing.
class MessageSearchHit extends Equatable {
  const MessageSearchHit({
    required this.message,
    required this.snippet,
    this.highlights = const <TextMatchRange>[],
    this.chat,
  });

  /// Builds a hit, or null when the message has nothing to show.
  ///
  /// [query] is matched by the server's rules rather than as one string:
  /// `бюджет догов` is two terms, and neither the whole query nor the last
  /// term in full will appear in the text.
  static MessageSearchHit? of(
    MessageEntity message,
    String query, {
    MessageSearchChat? chat,
  }) {
    final content = message.content;
    if (content == null || content.isEmpty) return null;

    final terms = MessageSearchTerms.of(query);
    final flat = content.replaceAll(RegExp(r'\s+'), ' ').trim();

    final start = terms.firstMatchIn(flat);
    if (start < 0) {
      // The index matched something this text does not show — a term past
      // the snippet, or a form the client cannot see. Still a real hit.
      return MessageSearchHit(
        message: message,
        snippet: _clamp(flat),
        chat: chat,
      );
    }

    final window = _windowAround(flat, start);

    return MessageSearchHit(
      message: message,
      snippet: window,
      highlights: terms.highlightsIn(window),
      chat: chat,
    );
  }

  static const int _maxSnippet = 120;
  static const int _lead = 24;

  static String _clamp(String text) => text.length <= _maxSnippet
      ? text
      : '${text.substring(0, _maxSnippet)}…';

  /// A message can be four thousand characters long (api-docs §5.4) and a
  /// result row has two lines, so the window is cut around the match rather
  /// than off the head of the text.
  static String _windowAround(String text, int matchStart) {
    if (text.length <= _maxSnippet) return text;

    var start = matchStart - _lead;
    if (start < 0) start = 0;

    var end = start + _maxSnippet;
    if (end > text.length) {
      end = text.length;
      start = end - _maxSnippet;
      if (start < 0) start = 0;
    }

    final head = start > 0 ? '…' : '';
    final tail = end < text.length ? '…' : '';

    return '$head${text.substring(start, end)}$tail';
  }

  final MessageEntity message;

  /// The message trimmed to a window around the match.
  final String snippet;

  /// Where the query's terms sit inside [snippet].
  final List<TextMatchRange> highlights;

  /// The chat the message was said in, when the answer carried one.
  final MessageSearchChat? chat;

  String get chatId => message.chatId;

  int get seq => message.seq;

  @override
  List<Object?> get props => [message, snippet, highlights, chat];
}

class MessageSearchResult extends Equatable {
  const MessageSearchResult({
    required this.hits,
    required this.source,
    this.hasNext = false,
    this.nextMessageId,
  });

  static const MessageSearchResult empty = MessageSearchResult(
    hits: [],
    source: MessageSearchSource.server,
  );

  final List<MessageSearchHit> hits;

  final MessageSearchSource source;

  /// More pages behind this one. A real field on the wire, not a count to
  /// work out (api-docs §5.4.1).
  final bool hasNext;

  /// Pass as `last_message_id` for the next page. Filled only when
  /// [hasNext].
  final String? nextMessageId;

  bool get isEmpty => hits.isEmpty;

  bool get canLoadMore => hasNext && nextMessageId != null;

  @override
  List<Object?> get props => [hits, source, hasNext, nextMessageId];
}
