import 'dart:async';

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
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';
import 'package:chatix/features/chat/data/repositories/chat_local_repository_impl.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

class MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// Opening a chat this device has seen before: the messages it already holds
/// go up first, the network catches up behind them, and the socket is given
/// the cached cursor so `ws.history` replays only what was missed (api-docs
/// §6.3).
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
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 3,
    unreadCount: 0,
  );

  MessageEntity message(int seq, {String body = 'hello'}) => MessageEntity(
    id: 'm$seq',
    chatId: chatId,
    seq: seq,
    authorId: 42,
    type: MessageType.text,
    content: body,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Map<String, dynamic> newMessageFrame(int seq, {String eventId = 'e-1'}) => {
    'type': 'new_message',
    'chat_id': chatId,
    'payload': {
      'event_id': eventId,
      'event_name': 'chats.message.created',
      'event': {
        'message_id': 'm$seq',
        'seq': seq,
        'sender_id': 42,
        'message_type': 'text',
      },
      'message': {
        'id': 'm$seq',
        'chat_id': chatId,
        'seq': seq,
        'author_id': 42,
        'type': 'text',
        'content': 'pushed $seq',
        'reply_to_id': null,
        'forwarded_from_chat_id': null,
        'forwarded_from_message_id': null,
        'forwarded_from_author_id': null,
        'is_edited': false,
        'created_at': '2026-01-01T00:00:00Z',
        'attachments': <Object?>[],
        'reactions': <Object?>[],
      },
    },
    'ts': '2026-01-01T00:00:00Z',
  };

  late ChatLocalStore store;
  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockMarkReadUseCase markRead;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;
  Uri? connectUri;

  setUp(() {
    store = inMemoryChatLocalStore();
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    markRead = MockMarkReadUseCase();
    channel = FakeWebSocketChannel();
    connectUri = null;
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (uri) {
        connectUri = uri;
        return channel;
      },
    );

    when(() => getChat.execute(chatId)).thenAnswer((_) async => Right(chat));
    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  Future<void> fillCache(List<MessageEntity> messages) =>
      ChatLocalRepositoryImpl(store).rememberMessages(chatId, messages);

  void answerMessages(Future<Either<Failure, MessagesPage>> Function() answer) {
    when(
      () => getMessages.execute(chatId, limit: any(named: 'limit')),
    ).thenAnswer((_) => answer());
  }

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [
        chatLocalDataSourceProvider.overrideWithValue(store),
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        markReadUseCaseProvider.overrideWithValue(markRead),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => FakeAuthController(me)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(chatDetailProvider(chatId), (_, _) {});
    return container;
  }

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('the cached messages are on screen before the fetch answers', () async {
    await fillCache([message(9, body: 'cached'), message(8)]);

    // A fetch that never answers stands in for a slow or missing network.
    final stuck = Completer<Either<Failure, MessagesPage>>();
    answerMessages(() => stuck.future);

    final container = boot();
    await container.read(authProvider.future);
    final state = await container.read(chatDetailProvider(chatId).future);

    expect(state.messages.map((m) => m.seq), [9, 8]);
    expect(state.messages.first.content, 'cached');
  });

  test('the fetch replaces the cached window when it lands', () async {
    await fillCache([message(9, body: 'cached')]);

    answerMessages(
      () async => Right(
        MessagesPage(
          messages: [message(11, body: 'fetched'), message(9, body: 'edited')],
          nextCursor: 8,
          hasNext: true,
        ),
      ),
    );

    final container = boot();
    await container.read(authProvider.future);
    await container.read(chatDetailProvider(chatId).future);
    await settle();

    final state = container.read(chatDetailProvider(chatId)).value!;
    expect(state.messages.map((m) => m.seq), [11, 9]);
    expect(state.messages.last.content, 'edited');
    expect(state.chat?.name, 'Team');
    expect(state.nextCursor, 8);
  });

  test('a failed catch-up leaves the cached chat on screen', () async {
    // Offline with a cache is a working chat, not an error page.
    await fillCache([message(9, body: 'cached')]);
    answerMessages(() async => const Left(NetworkFailure()));

    final container = boot();
    await container.read(authProvider.future);
    await container.read(chatDetailProvider(chatId).future);
    await settle();

    final state = container.read(chatDetailProvider(chatId)).value!;
    expect(state.messages.single.content, 'cached');
    expect(container.read(chatDetailProvider(chatId)).hasError, isFalse);
  });

  test('the gateway is handed the cached cursor at the handshake', () async {
    // One open chat with a known cursor goes in the connect URL rather than
    // in a `subscribe` frame: the gateway subscribes for us right after
    // `ws.ready`, saving a round trip on every reconnect (api-docs §6.1).
    await fillCache([message(9), message(8)]);

    final stuck = Completer<Either<Failure, MessagesPage>>();
    answerMessages(() => stuck.future);

    final container = boot();
    await container.read(authProvider.future);
    await container.read(chatDetailProvider(chatId).future);
    await socket.connect();
    await settle();

    expect(connectUri?.queryParameters['initial_chat_id'], chatId);
    expect(connectUri?.queryParameters['initial_last_seq'], '9');
  });

  test('messages pushed over the socket are kept for next time', () async {
    await fillCache([message(9)]);
    answerMessages(
      () async => Right(
        MessagesPage(messages: [message(9)], nextCursor: null, hasNext: false),
      ),
    );

    final container = boot();
    await container.read(authProvider.future);
    await container.read(chatDetailProvider(chatId).future);
    await socket.connect();

    channel.emit(newMessageFrame(10));
    await settle();

    expect(
      store.readMessages(chatId).map((row) => row['seq']),
      contains(10),
    );
  });

  test('a skipped seq sends the client back for the window', () async {
    await fillCache([message(9)]);

    var fetches = 0;
    answerMessages(() async {
      fetches++;
      return Right(
        MessagesPage(messages: [message(9)], nextCursor: null, hasNext: false),
      );
    });

    final container = boot();
    await container.read(authProvider.future);
    await container.read(chatDetailProvider(chatId).future);
    await socket.connect();
    await settle();

    final beforeGap = fetches;

    // 10 never arrived — missed, or deleted before it ever did. Either way
    // the window on screen has stopped describing the chat.
    channel.emit(newMessageFrame(11));
    await settle();

    expect(fetches, greaterThan(beforeGap));
  });

  test('the next seq in line is not a gap and costs nothing', () async {
    await fillCache([message(9)]);

    var fetches = 0;
    answerMessages(() async {
      fetches++;
      return Right(
        MessagesPage(messages: [message(9)], nextCursor: null, hasNext: false),
      );
    });

    final container = boot();
    await container.read(authProvider.future);
    await container.read(chatDetailProvider(chatId).future);
    await socket.connect();
    await settle();

    final beforePush = fetches;

    channel.emit(newMessageFrame(10));
    await settle();

    expect(fetches, beforePush);
  });

  test('an empty cache still loads the ordinary way', () async {
    answerMessages(
      () async => Right(
        MessagesPage(messages: [message(3)], nextCursor: null, hasNext: false),
      ),
    );

    final container = boot();
    await container.read(authProvider.future);
    final state = await container.read(chatDetailProvider(chatId).future);

    expect(state.messages.map((m) => m.seq), [3]);
    expect(state.chat?.name, 'Team');
  });
}
