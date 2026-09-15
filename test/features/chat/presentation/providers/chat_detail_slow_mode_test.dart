import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/composer_provider.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

class MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class MockSendMessageUseCase extends Mock implements SendMessageUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// `429 SLOW_MODE_LIMIT` carries the only clock that counts (api-docs §2.6).
/// The composer draws the countdown, so the refusal has to reach it — and
/// the message has to stay pending under the same idempotency key, so the
/// retry is the same message rather than a second one (§5.4).
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  final chat = ChatEntity(
    id: chatId,
    seqCounter: 100,
    lastActivityAt: DateTime.utc(2026, 1, 1),
    type: ChatType.group,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 30,
    permissions: const {},
    createdBy: 1,
    memberCount: 3,
    unreadCount: 0,
  );

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockMarkReadUseCase markRead;
  late MockSendMessageUseCase sendMessage;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    markRead = MockMarkReadUseCase();
    sendMessage = MockSendMessageUseCase();
    channel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => channel,
    );

    when(() => getChat.execute(chatId)).thenAnswer((_) async => Right(chat));
    when(
      () => getMessages.execute(chatId, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => const Right(
        MessagesPage(messages: [], nextCursor: null, hasNext: false),
      ),
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

  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        markReadUseCaseProvider.overrideWithValue(markRead),
        sendMessageUseCaseProvider.overrideWithValue(sendMessage),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => FakeAuthController(me)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.listen(chatDetailProvider(chatId), (_, _) {});
    container.listen(composerProvider(chatId), (_, _) {});
    await container.read(chatDetailProvider(chatId).future);

    return container;
  }

  ApiFailure slowMode(Object? retryAfter) => ApiFailure(
    code: 'SLOW_MODE_LIMIT',
    message: 'Too fast',
    detail: {'chat_id': chatId, 'retry_after': retryAfter},
    status: 429,
  );

  test('a slow-mode refusal starts the composer countdown', () async {
    answerSend(Left(slowMode(42)));
    final container = await boot();

    await container
        .read(chatDetailProvider(chatId).notifier)
        .sendMessage(content: 'hello');

    final wait = container
        .read(composerProvider(chatId))
        .slowMode
        .secondsLeftAt(DateTime.now());

    expect(wait, closeTo(42, 1));
  });

  test('a fractional retry_after is rounded up rather than dropped', () async {
    answerSend(Left(slowMode(4.2)));
    final container = await boot();

    await container
        .read(chatDetailProvider(chatId).notifier)
        .sendMessage(content: 'hello');

    expect(
      container
          .read(composerProvider(chatId))
          .slowMode
          .secondsLeftAt(DateTime.now()),
      closeTo(5, 1),
    );
  });

  test('the message stays pending, under the key it was sent with', () async {
    answerSend(Left(slowMode(30)));
    final container = await boot();

    await container
        .read(chatDetailProvider(chatId).notifier)
        .sendMessage(content: 'hello');

    final pending = container.read(chatDetailProvider(chatId)).value!.pending;
    expect(pending, hasLength(1));
    expect(pending.single.failureMessage, 'Too fast');
    // 429 is the server saying "later", so the queue keeps the message and
    // will try again on its own; it is not a message to be rescued by hand.
    expect(pending.single.needsAttention, isFalse);

    // Retrying reuses the key, which is the whole point of generating one
    // per message rather than per attempt (api-docs §5.4).
    final key = pending.single.idempotencyKey;
    answerSend(
      Right(
        MessageEntity(
          id: 'm1',
          chatId: chatId,
          seq: 1,
          authorId: 7,
          type: MessageType.text,
          content: 'hello',
          replyToId: null,
          forwardedFromChatId: null,
          forwardedFromMessageId: null,
          forwardedFromAuthorId: null,
          isEdited: false,
          createdAt: DateTime.utc(2026, 1, 1),
          attachments: const [],
        ),
      ),
    );

    await container
        .read(chatDetailProvider(chatId).notifier)
        .retry(pending.single);

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

  test('an ordinary failure leaves the clock alone', () async {
    answerSend(const Left(NetworkFailure()));
    final container = await boot();

    await container
        .read(chatDetailProvider(chatId).notifier)
        .sendMessage(content: 'hello');

    expect(
      container
          .read(composerProvider(chatId))
          .slowMode
          .canSendAt(DateTime.now()),
      isTrue,
    );
  });
}
