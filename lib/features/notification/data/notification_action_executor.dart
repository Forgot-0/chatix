import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/notification/domain/entities/push_message.dart';

/// Carries out what the reader asked for from the shade.
///
/// Built on [ChatRestDataSource] rather than on the chat repository because it
/// also has to run in the background isolate a notification action wakes up,
/// where there is no provider graph and no local cache — the data source needs
/// nothing but an `ApiClient`.
class NotificationActionExecutor {
  const NotificationActionExecutor(this._chat);

  final ChatRestDataSource _chat;

  Future<Either<Failure, void>> execute(NotificationActionEvent event) {
    final message = PushMessage.fromPayload(event.payload);

    switch (event.action) {
      case NotificationActionType.reply:
        return _reply(message, event.replyText);
      case NotificationActionType.markRead:
        return _markRead(message);
      case null:
        return Future.value(
          const Left(InputFailure(message: 'Notification carried no action')),
        );
    }
  }

  Future<Either<Failure, void>> _reply(
    PushMessage message,
    String? text,
  ) async {
    final chatId = message.chatId;
    final trimmed = text?.trim();

    if (chatId == null) {
      return const Left(
        InputFailure(message: 'Notification carried no chat to reply to'),
      );
    }
    if (trimmed == null || trimmed.isEmpty) {
      return const Left(InputFailure(message: 'Cannot send an empty message'));
    }

    final replyToId = message.messageId;

    final result = await _chat.sendMessage(
      chatId,
      content: trimmed,
      replyToId: replyToId,
      messageType: replyToId == null ? MessageType.text : MessageType.reply,
    );

    return result.map((_) {});
  }

  /// Marking read wants a `seq` (api-docs §5.4 `MarkReadRequest`), and a push
  /// payload does not reliably carry one; when it does not, the message is
  /// fetched to learn it rather than guessing.
  Future<Either<Failure, void>> _markRead(PushMessage message) async {
    final chatId = message.chatId;
    if (chatId == null) {
      return const Left(
        InputFailure(message: 'Notification carried no chat to mark read'),
      );
    }

    var seq = message.messageSeq;

    if (seq == null) {
      final messageId = message.messageId;
      if (messageId == null) {
        return const Left(
          InputFailure(
            message:
                'Nothing in the notification says how far to mark this chat '
                'read',
          ),
        );
      }

      final fetched = await _chat.fetchMessage(chatId, messageId);
      final resolved = fetched.toNullable();
      if (resolved == null) return fetched.map((_) {});
      seq = resolved.seq;
    }

    return _chat.markRead(chatId, seq);
  }
}
