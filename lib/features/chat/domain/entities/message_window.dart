import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// The rules for holding one chat's messages, wherever they came from.
///
/// A chat screen is fed by three sources at once — what the cache had when
/// the screen opened, what `GET /messages/` answers a moment later, and what
/// the socket pushes from then on — and all three can describe the same
/// message. These are the rules that turn them into one list: newest first,
/// one entry per message, and the freshest description of each wins.
///
/// Pure on purpose: everything here is a function of its arguments, so the
/// awkward cases (a gap in `seq`, an edit arriving before the original, a
/// cached page that overlaps the fetched one) are testable without a socket
/// or a database.
abstract final class MessageWindow {
  /// Folds [incoming] into [current], newest first.
  ///
  /// Identity is the message id, with `seq` as the tie-breaker: the same
  /// message can arrive as a cached row, a REST row and a WS row, and only
  /// one of them belongs in the list. Later sources win, because every
  /// caller hands over the fresher list as [incoming].
  static List<MessageEntity> merge(
    Iterable<MessageEntity> current,
    Iterable<MessageEntity> incoming,
  ) {
    final byId = <String, MessageEntity>{};
    final seqToId = <int, String>{};

    void put(MessageEntity message) {
      // A seq is unique within a chat, so a second message claiming one
      // already taken is the same message re-identified — a locally cached
      // copy of something the server has since restated. Keep the newcomer.
      final holder = seqToId[message.seq];
      if (holder != null && holder != message.id) byId.remove(holder);

      byId[message.id] = message;
      seqToId[message.seq] = message.id;
    }

    for (final message in current) {
      put(message);
    }
    for (final message in incoming) {
      put(message);
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.seq.compareTo(a.seq));
    return merged;
  }

  /// Takes [authoritative] as the whole truth for the span of `seq` it
  /// covers, dropping anything cached inside that span it does not mention.
  ///
  /// That is how a deletion this device slept through is noticed: the
  /// message is simply absent from the page the server just sent, and
  /// nothing else says so — `message_deleted` was delivered to a socket that
  /// was not connected. Outside the span nothing is dropped: a message older
  /// than the page is not deleted, it is merely not on this page.
  static List<MessageEntity> reconcile(
    Iterable<MessageEntity> current,
    List<MessageEntity> authoritative,
  ) {
    if (authoritative.isEmpty) return merge(current, const []);

    final lowest = lowestSeq(authoritative)!;
    final highest = highestSeq(authoritative)!;
    final kept = {for (final message in authoritative) message.id};

    final survivors = [
      for (final message in current)
        if (message.seq < lowest ||
            message.seq > highest ||
            kept.contains(message.id))
          message,
    ];

    return merge(survivors, authoritative);
  }

  /// Whether [incoming] proves messages were missed.
  ///
  /// Realtime delivery is per-message, so the seq of a pushed message should
  /// be the next one this device knows about. A jump means either a message
  /// never reached us or one was deleted before we ever saw it — from here
  /// the two are indistinguishable, and both are answered the same way: stop
  /// trusting the window and fetch it again.
  ///
  /// False when there is nothing to compare against: the first message of an
  /// empty screen is not a gap.
  static bool isGap(Iterable<MessageEntity> known, MessageEntity incoming) {
    final highest = highestSeq(known);
    if (highest == null) return false;
    if (incoming.seq <= highest) return false;
    return incoming.seq > highest + 1;
  }

  static int? highestSeq(Iterable<MessageEntity> messages) {
    int? highest;
    for (final message in messages) {
      if (highest == null || message.seq > highest) highest = message.seq;
    }
    return highest;
  }

  static int? lowestSeq(Iterable<MessageEntity> messages) {
    int? lowest;
    for (final message in messages) {
      if (lowest == null || message.seq < lowest) lowest = message.seq;
    }
    return lowest;
  }

  /// The newest [limit] messages, for the caller that has to put a bound on
  /// what it keeps.
  static List<MessageEntity> newest(
    Iterable<MessageEntity> messages,
    int limit,
  ) {
    final sorted = messages.toList()..sort((a, b) => b.seq.compareTo(a.seq));
    return sorted.length <= limit ? sorted : sorted.sublist(0, limit);
  }
}
