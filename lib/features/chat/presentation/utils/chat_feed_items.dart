import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/message_grouping.dart';

/// One row of the conversation, in the order a reverse list wants them:
/// index 0 is the newest, the bottom of the screen.
///
/// The feed is flattened ahead of building so that everything the list has to
/// answer about a row — which day it belongs to, whether it opens a run,
/// whether the unread rule fires on it — is decided once, off the build path,
/// and can be asked about by index. The sticky header and the read cursor both
/// work from indices the viewport hands back, so they need exactly that.
sealed class ChatFeedItem extends Equatable {
  const ChatFeedItem();

  /// Stable across rebuilds and across pages loading above: what the list
  /// keys its children on, so prepending history recycles instead of
  /// reshuffling.
  String get key;
}

/// A message that has been handed to the API but not yet acknowledged.
final class FeedPendingItem extends ChatFeedItem {
  const FeedPendingItem({required this.index, required this.idempotencyKey});

  /// Position in `ChatDetailState.pending`.
  final int index;

  final String idempotencyKey;

  @override
  String get key => 'pending:$idempotencyKey';

  @override
  List<Object?> get props => [index, idempotencyKey];
}

/// A message the server has confirmed, with every layout decision resolved.
final class FeedMessageItem extends ChatFeedItem {
  const FeedMessageItem({
    required this.index,
    required this.message,
    required this.isMine,
    required this.startsGroup,
    required this.endsGroup,
    required this.showsDate,
    required this.showsUnread,
    required this.showsAvatar,
    required this.hasAvatarGutter,
  });

  /// Position in `ChatDetailState.messages`.
  final int index;

  final MessageEntity message;

  final bool isMine;

  /// First message of a run by one author: the row that carries the avatar
  /// and the name.
  final bool startsGroup;

  /// Last message of a run: the row that carries the time and the ticks.
  final bool endsGroup;

  final bool showsDate;

  /// The "unread messages" rule fires here. Placed from the read cursor
  /// frozen at open, so it does not travel as new messages land.
  final bool showsUnread;

  final bool showsAvatar;

  /// Incoming message in a group chat that is not the head of its run: no
  /// avatar, but the gutter is still held open so the run stays aligned.
  final bool hasAvatarGutter;

  /// The reader's calendar day, which is what the sticky header names.
  DateTime get day {
    final local = message.createdAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @override
  String get key => 'message:${message.id}';

  @override
  List<Object?> get props => [
    index,
    message,
    isMine,
    startsGroup,
    endsGroup,
    showsDate,
    showsUnread,
    showsAvatar,
    hasAvatarGutter,
  ];
}

/// The spinner at the far end of the loaded window, where backward paging
/// picks up.
final class FeedLoadMoreItem extends ChatFeedItem {
  const FeedLoadMoreItem();

  @override
  String get key => 'load-more';

  @override
  List<Object?> get props => const [];
}

abstract final class ChatFeedBuilder {
  /// Flattens a loaded window into rows.
  ///
  /// [messages] arrives newest first, the order `GET /messages/` returns
  /// (api-docs §5.4, `direction="backward"`), and comes back out in that same
  /// order so indices line up with a reverse list.
  static List<ChatFeedItem> build({
    required List<MessageEntity> messages,
    required List<String> pendingKeys,
    required bool canLoadMore,
    required int? unreadAnchorSeq,
    required int? myUserId,
    required bool isGroupChat,
  }) {
    final items = <ChatFeedItem>[];

    // Pending sits below everything: the newest thing on screen is whatever
    // was typed last. `pending` is stored oldest first, so it is walked back
    // to front.
    for (var i = pendingKeys.length - 1; i >= 0; i--) {
      items.add(FeedPendingItem(index: i, idempotencyKey: pendingKeys[i]));
    }

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final older = i + 1 < messages.length ? messages[i + 1] : null;
      final newer = i > 0 ? messages[i - 1] : null;

      final isMine = myUserId != null && message.authorId == myUserId;
      final startsGroup = MessageGrouping.startsGroup(older, message);
      final isIncomingInGroup =
          isGroupChat && !isMine && message.type != MessageType.system;

      // Above the oldest loaded message there may be history we have not
      // fetched. Claiming the run, the day or the unread boundary starts
      // there would be a guess, and a guess that moves once the page above
      // arrives.
      final isOldestWithMore = older == null && canLoadMore;

      items.add(
        FeedMessageItem(
          index: i,
          message: message,
          isMine: isMine,
          startsGroup: startsGroup,
          endsGroup: MessageGrouping.startsGroup(message, newer),
          showsDate:
              !isOldestWithMore &&
              (older == null ||
                  !MessageGrouping.sameDay(older.createdAt, message.createdAt)),
          showsUnread:
              !isOldestWithMore &&
              MessageGrouping.startsUnread(
                lastReadSeq: unreadAnchorSeq,
                older: older,
                current: message,
                myUserId: myUserId,
              ),
          showsAvatar: isIncomingInGroup && startsGroup,
          hasAvatarGutter: isIncomingInGroup,
        ),
      );
    }

    if (canLoadMore) items.add(const FeedLoadMoreItem());

    return items;
  }

  /// Where the unread rule fired, or null when this window does not contain
  /// the boundary.
  static int? unreadIndexOf(List<ChatFeedItem> items) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is FeedMessageItem && item.showsUnread) return i;
    }
    return null;
  }

  /// The day the row at [index] belongs to, for the header that sticks to the
  /// top of the viewport. Rows that are not messages borrow the nearest
  /// message below them, which is the day their block belongs to.
  static DateTime? dayAt(List<ChatFeedItem> items, int index) {
    for (var i = math.min(index, items.length - 1); i >= 0; i--) {
      final item = items[i];
      if (item is FeedMessageItem) return item.day;
    }
    return null;
  }

  /// How many messages sit below the reader's furthest point, which is what
  /// the jump-to-bottom badge counts. Own messages never count: they were not
  /// news to the person who sent them.
  ///
  /// A null [seenSeq] means no row has been on screen yet, which happens only
  /// before the first frame — nothing is owed a badge at that point.
  static int countNewerThan(
    List<MessageEntity> messages, {
    required int? seenSeq,
    required int? myUserId,
  }) {
    if (seenSeq == null) return 0;

    var count = 0;
    for (final message in messages) {
      // Sorted newest first, so the first message at or below the cursor ends
      // the run.
      if (message.seq <= seenSeq) break;
      if (myUserId != null && message.authorId == myUserId) continue;
      count++;
    }
    return count;
  }
}
