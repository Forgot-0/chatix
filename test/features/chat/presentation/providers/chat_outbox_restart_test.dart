import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/outbox_entry.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_outbox_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockSendMessageUseCase extends Mock implements SendMessageUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

/// The queue's whole reason for existing: a message typed with no connection
/// is still sent, after the app has been closed and opened again, and it is
/// sent once — the `Idempotency-Key` is generated when the message is written
/// and never again (api-docs §5.4).
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  late ChatLocalStore store;
  late MockSendMessageUseCase sendMessage;
  late MockMarkReadUseCase markRead;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  final sent = MessageEntity(
    id: 'm1',
    chatId: chatId,
    seq: 12,
    authorId: 7,
    type: MessageType.text,
    content: 'unsent',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    store = inMemoryChatLocalStore();
    sendMessage = MockSendMessageUseCase();
    markRead = MockMarkReadUseCase();
    channel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(),
      channelFactory: (_) => channel,
    );

    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  void answerSend(Either<Failure, MessageEntity> result) {
    when(
      () => sendMessage.execute(
        chatId,
        content: any(named: 'content'),
        replyToId: any(named: 'replyToId'),
        uploadTokens: any(named: 'uploadTokens'),
        messageType: any(named: 'messageType'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// One run of the app. The store outlives it; the container does not.
  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [
        chatLocalDataSourceProvider.overrideWithValue(store),
        sendMessageUseCaseProvider.overrideWithValue(sendMessage),
        markReadUseCaseProvider.overrideWithValue(markRead),
        chatSocketServiceProvider.overrideWithValue(socket),
      ],
    );
    addTearDown(container.dispose);
    container.listen(chatOutboxProvider, (_, _) {});
    return container;
  }

  test('a message that could not be sent is still queued next time', () async {
    answerSend(const Left(NetworkFailure()));

    final first = boot();
    first.read(chatOutboxProvider.notifier).enqueueMessage(
      chatId,
      content: 'unsent',
    );
    await first.read(chatOutboxProvider.notifier).drain();

    final queued = first.read(chatOutboxProvider);
    expect(queued, hasLength(1));
    final key = queued.single.id;

    first.dispose();

    // A new run, reading the queue off the same store.
    answerSend(Right(sent));
    final second = boot();

    final restored = second.read(chatOutboxProvider);
    expect(restored, hasLength(1));
    expect(restored.single.id, key, reason: 'the key is the entry id');
    expect(
      (restored.single.operation as OutboxSendMessage).content,
      'unsent',
    );

    await second.read(chatOutboxProvider.notifier).drain();

    expect(second.read(chatOutboxProvider), isEmpty);

    // Twice with one key: once in the run that failed, once in the run that
    // worked. That is what stops the retry being a second message — the
    // server answers the second call out of the 24-hour idempotency cache
    // if the first one did reach it (api-docs §5.4).
    verify(
      () => sendMessage.execute(
        chatId,
        content: any(named: 'content'),
        replyToId: any(named: 'replyToId'),
        uploadTokens: any(named: 'uploadTokens'),
        messageType: any(named: 'messageType'),
        idempotencyKey: key,
      ),
    ).called(2);
  });

  test('a delivered message leaves the store behind it', () async {
    answerSend(Right(sent));

    final container = boot();
    container.read(chatOutboxProvider.notifier).enqueueMessage(
      chatId,
      content: 'unsent',
    );
    await container.read(chatOutboxProvider.notifier).drain();

    expect(store.readOutbox(), isEmpty);
    expect(boot().read(chatOutboxProvider), isEmpty);
  });

  test('the attempt count survives, so chances are not renewed', () async {
    // Otherwise closing and opening the app is a way to get seven more
    // attempts at a message the server will keep refusing.
    answerSend(const Left(NetworkFailure()));

    final first = boot();
    first.read(chatOutboxProvider.notifier).enqueueMessage(
      chatId,
      content: 'unsent',
    );
    await first.read(chatOutboxProvider.notifier).drain();
    first.dispose();

    final second = boot();
    expect(second.read(chatOutboxProvider).single.attempts, 1);

    // The backoff it was waiting out died with the process, so it is due now
    // rather than at a moment that has already passed.
    expect(second.read(chatOutboxProvider).single.nextAttemptAt, isNull);
  });

  test('a read cursor queued offline is reported once, at its furthest',
      () async {
    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Left(NetworkFailure()));

    final first = boot();
    final outbox = first.read(chatOutboxProvider.notifier);
    outbox.enqueueRead(chatId, 10);
    await outbox.drain();
    outbox.enqueueRead(chatId, 44);
    outbox.enqueueRead(chatId, 120);

    expect(
      first.read(chatOutboxProvider).where(
            (entry) => entry.operation is OutboxRead,
          ),
      hasLength(2),
      reason: 'the attempted one is left alone; the rest collapse into one',
    );

    first.dispose();

    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));

    final second = boot();
    await second.read(chatOutboxProvider.notifier).drain();

    expect(second.read(chatOutboxProvider), isEmpty);
    verify(() => markRead.execute(chatId, 120)).called(1);
  });

  test('a refusal that cannot be retried waits for a person', () async {
    answerSend(
      const Left(
        ApiFailure(
          code: 'MESSAGE_TOO_LONG',
          message: 'too long',
          detail: null,
          status: 400,
        ),
      ),
    );

    final container = boot();
    container.read(chatOutboxProvider.notifier).enqueueMessage(
      chatId,
      content: 'unsent',
    );
    await container.read(chatOutboxProvider.notifier).drain();

    final stuck = container.read(chatOutboxProvider).single;
    expect(stuck.needsAttention, isTrue);
    expect(stuck.failureMessage, 'too long');

    // And it stops trying: another pass leaves it exactly where it was.
    await container.read(chatOutboxProvider.notifier).drain();
    verify(
      () => sendMessage.execute(
        chatId,
        content: any(named: 'content'),
        replyToId: any(named: 'replyToId'),
        uploadTokens: any(named: 'uploadTokens'),
        messageType: any(named: 'messageType'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);

    // Until it is thrown away.
    await container.read(chatOutboxProvider.notifier).discard(stuck.id);
    expect(container.read(chatOutboxProvider), isEmpty);
    expect(store.readOutbox(), isEmpty);
  });
}
