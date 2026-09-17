import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/notification/data/notification_action_executor.dart';

class _MockChat extends Mock implements ChatRestDataSource {}

MessageModel _message({required int seq}) {
  return MessageModel(
    id: 'm-1',
    chatId: 'c-1',
    seq: seq,
    authorId: 5,
    type: MessageType.text.wire,
    content: 'Hello',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: '2026-09-17T10:00:00Z',
    attachments: const [],
    reactions: const [],
  );
}

/// The buttons in the shade are answered for real — including from the
/// background isolate — so what they send has to be exactly what the chat
/// endpoints expect (api-docs §5.4).
void main() {
  late _MockChat chat;
  late NotificationActionExecutor executor;

  setUpAll(() {
    registerFallbackValue(MessageType.text);
  });

  setUp(() {
    chat = _MockChat();
    executor = NotificationActionExecutor(chat);
  });

  NotificationActionEvent event({
    required NotificationActionType action,
    Map<String, dynamic> payload = const {'chat_id': 'c-1', 'message_id': 'm-1'},
    String? replyText,
  }) {
    return NotificationActionEvent(
      notificationId: 'n-1',
      payload: payload,
      action: action,
      replyText: replyText,
    );
  }

  group('reply', () {
    test('sends the typed text as a reply to the message', () async {
      when(
        () => chat.sendMessage(
          any(),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          messageType: any(named: 'messageType'),
        ),
      ).thenAnswer((_) async => Right(_message(seq: 3)));

      final result = await executor.execute(
        event(action: NotificationActionType.reply, replyText: '  On my way '),
      );

      expect(result.isRight(), isTrue);
      verify(
        () => chat.sendMessage(
          'c-1',
          content: 'On my way',
          replyToId: 'm-1',
          messageType: MessageType.reply,
        ),
      ).called(1);
    });

    test('sends a plain message when the payload names no message', () async {
      when(
        () => chat.sendMessage(
          any(),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          messageType: any(named: 'messageType'),
        ),
      ).thenAnswer((_) async => Right(_message(seq: 3)));

      await executor.execute(
        event(
          action: NotificationActionType.reply,
          payload: const {'chat_id': 'c-1'},
          replyText: 'Hi',
        ),
      );

      verify(
        () => chat.sendMessage(
          'c-1',
          content: 'Hi',
          replyToId: null,
          messageType: MessageType.text,
        ),
      ).called(1);
    });

    test('an empty reply is refused rather than sent', () async {
      final result = await executor.execute(
        event(action: NotificationActionType.reply, replyText: '   '),
      );

      expect(result.isLeft(), isTrue);
      verifyNever(
        () => chat.sendMessage(
          any(),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          messageType: any(named: 'messageType'),
        ),
      );
    });

    test('a payload with no chat is refused', () async {
      final result = await executor.execute(
        event(
          action: NotificationActionType.reply,
          payload: const {'body': 'Hello'},
          replyText: 'Hi',
        ),
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('mark read', () {
    test('uses the seq the payload carried', () async {
      when(
        () => chat.markRead(any(), any()),
      ).thenAnswer((_) async => const Right(null));

      final result = await executor.execute(
        event(
          action: NotificationActionType.markRead,
          payload: const {'chat_id': 'c-1', 'message_seq': '12'},
        ),
      );

      expect(result.isRight(), isTrue);
      verify(() => chat.markRead('c-1', 12)).called(1);
      verifyNever(() => chat.fetchMessage(any(), any()));
    });

    test('fetches the message to learn the seq when it is missing', () async {
      when(
        () => chat.fetchMessage(any(), any()),
      ).thenAnswer((_) async => Right(_message(seq: 9)));
      when(
        () => chat.markRead(any(), any()),
      ).thenAnswer((_) async => const Right(null));

      final result = await executor.execute(
        event(action: NotificationActionType.markRead),
      );

      expect(result.isRight(), isTrue);
      verify(() => chat.fetchMessage('c-1', 'm-1')).called(1);
      verify(() => chat.markRead('c-1', 9)).called(1);
    });

    test('gives up when neither a seq nor a message id is there', () async {
      final result = await executor.execute(
        event(
          action: NotificationActionType.markRead,
          payload: const {'chat_id': 'c-1'},
        ),
      );

      expect(result.isLeft(), isTrue);
      verifyNever(() => chat.markRead(any(), any()));
    });

    test('passes the failure on when the message cannot be fetched', () async {
      when(() => chat.fetchMessage(any(), any())).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'gone')),
      );

      final result = await executor.execute(
        event(action: NotificationActionType.markRead),
      );

      expect(result.isLeft(), isTrue);
      verifyNever(() => chat.markRead(any(), any()));
    });
  });

  test('a tap on the body itself is not an action to carry out', () async {
    final result = await executor.execute(
      const NotificationActionEvent(
        notificationId: 'n-1',
        payload: {'chat_id': 'c-1'},
      ),
    );

    expect(result.isLeft(), isTrue);
  });
}
