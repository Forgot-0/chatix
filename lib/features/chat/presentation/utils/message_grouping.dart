import 'package:chatix/features/chat/domain/entities/message_entity.dart';

abstract final class MessageGrouping {
  static const Duration groupWindow = Duration(minutes: 5);

  static bool startsGroup(MessageEntity? previous, MessageEntity? current) {
    if (current == null) return true;
    if (previous == null) return true;
    if (previous.authorId != current.authorId) return true;
    if (previous.type == MessageType.system ||
        current.type == MessageType.system) {
      return true;
    }
    if (!sameDay(previous.createdAt, current.createdAt)) return true;
    return current.createdAt.difference(previous.createdAt) > groupWindow;
  }

  static bool sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  static bool startsUnread({
    required int? lastReadSeq,
    required MessageEntity? older,
    required MessageEntity current,
    required int? myUserId,
  }) {
    if (lastReadSeq == null || lastReadSeq <= 0) return false;
    if (current.authorId == myUserId) return false;
    if (current.seq <= lastReadSeq) return false;
    return older == null || older.seq <= lastReadSeq;
  }
}
