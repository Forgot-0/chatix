import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_context_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/in_chat_search_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

class MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class MockGetMessagesContextUseCase extends Mock
    implements GetMessagesContextUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

/// Searching inside one chat finds what the device has, and then asks the
/// server for the window around it — `GET /chats/{id}/messages/context/`
/// (api-docs §5.4) — which is the only way to open a match that was found in
/// a preview of history nobody has loaded.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const otherChatId = '550e8400-e29b-41d4-a716-446655440001';

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  final chat = ChatEntity(
    id: chatId,
    seqCounter: 20,
    lastActivityAt: DateTime.utc(2026, 3, 10),
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

  MessageEntity message(String chat, int seq, String content) => MessageEntity(
    id: '$chat-$seq',
    chatId: chat,
    seq: seq,
    authorId: 9,
    type: MessageType.text,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 3, 10, seq),
  );

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockGetMessagesContextUseCase getContext;
  late MockMarkReadUseCase markRead;
  late InMemoryMessageCacheStore store;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    getContext = MockGetMessagesContextUseCase();
    markRead = MockMarkReadUseCase();
    store = InMemoryMessageCacheStore();
    channel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => channel,
    );

    when(() => getChat.execute(any())).thenAnswer((_) async => Right(chat));
    when(
      () => getMessages.execute(any(), limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Right(
        MessagesPage(
          messages: [message(chatId, 20, 'nothing to see')],
          nextCursor: null,
          hasNext: false,
        ),
      ),
    );
    when(() => markRead.execute(any(), any())).thenAnswer(
      (_) async => const Right(null),
    );
    when(
      () => getContext.execute(any(), any(), limit: any(named: 'limit')),
    ).thenAnswer(
      (invocation) async => Right(
        MessagesPage(
          messages: [
            message(chatId, invocation.positionalArguments[1] as int, 'ship it'),
          ],
          nextCursor: null,
          hasNext: false,
        ),
      ),
    );
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        getMessagesContextUseCaseProvider.overrideWithValue(getContext),
        markReadUseCaseProvider.overrideWithValue(markRead),
        messageCacheStoreProvider.overrideWithValue(store),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(_FakeAuthController.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);

    // Both providers dispose themselves when nothing is watching, the way
    // they do when the screen closes; here the test stands in for the screen.
    final chatSubscription = container.listen(
      chatDetailProvider(chatId),
      (_, _) {},
    );
    addTearDown(chatSubscription.close);

    await container.read(chatDetailProvider(chatId).future);

    final searchSubscription = container.listen(
      inChatSearchProvider(chatId),
      (_, _) {},
    );
    addTearDown(searchSubscription.close);

    return container;
  }

  Future<void> settle() => Future<void>.delayed(
    const Duration(milliseconds: 20),
  );

  InChatSearchState stateOf(ProviderContainer container) =>
      container.read(inChatSearchProvider(chatId));

  test('what the chat has loaded is searchable at once', () async {
    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('nothing');
    await settle();

    expect(stateOf(container).hits, hasLength(1));
    expect(stateOf(container).hits.single.seq, 20);
  });

  test('it searches this chat only', () async {
    final container = await boot();
    store.remember(otherChatId, [message(otherChatId, 3, 'nothing here')]);

    container.read(inChatSearchProvider(chatId).notifier).submit('nothing');
    await settle();

    expect(stateOf(container).hits.map((h) => h.chatId), [chatId]);
  });

  test('matches are newest first and the newest is opened', () async {
    final container = await boot();
    store.remember(chatId, [
      message(chatId, 4, 'ship it'),
      message(chatId, 9, 'ship it again'),
    ]);

    container.read(inChatSearchProvider(chatId).notifier).submit('ship');
    await settle();

    expect(stateOf(container).hits.map((h) => h.seq), [9, 4]);
    expect(stateOf(container).position, 1);

    // Opening a match the screen has not loaded is a context request.
    verify(() => getContext.execute(chatId, 9, limit: any(named: 'limit')))
        .called(1);
  });

  test('the arrows walk the matches and take the chat with them', () async {
    final container = await boot();
    store.remember(chatId, [
      message(chatId, 4, 'ship it'),
      message(chatId, 9, 'ship it again'),
    ]);

    final controller = container.read(inChatSearchProvider(chatId).notifier);
    controller.submit('ship');
    await settle();

    expect(stateOf(container).canGoNewer, isFalse);
    expect(stateOf(container).canGoOlder, isTrue);

    await controller.goOlder();

    expect(stateOf(container).position, 2);
    expect(stateOf(container).canGoOlder, isFalse);
    verify(() => getContext.execute(chatId, 4, limit: any(named: 'limit')))
        .called(1);

    await controller.goNewer();
    expect(stateOf(container).position, 1);
  });

  test('the arrows stop at the ends instead of wrapping around', () async {
    final container = await boot();
    store.remember(chatId, [message(chatId, 4, 'ship it')]);

    final controller = container.read(inChatSearchProvider(chatId).notifier);
    controller.submit('ship');
    await settle();

    await controller.goNewer();
    await controller.goOlder();

    expect(stateOf(container).index, 0);
  });

  test('a match already on screen needs no request', () async {
    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('nothing');
    await settle();

    verifyNever(
      () => getContext.execute(any(), any(), limit: any(named: 'limit')),
    );
  });

  test('typing waits for the typing to stop', () async {
    final container = await boot();
    final controller = container.read(inChatSearchProvider(chatId).notifier);

    controller.type('not');
    expect(stateOf(container).isSearching, isTrue);
    expect(stateOf(container).hits, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 320));

    expect(stateOf(container).hits, hasLength(1));
    expect(stateOf(container).isSearching, isFalse);
  });

  test('clearing puts everything back', () async {
    final container = await boot();

    final controller = container.read(inChatSearchProvider(chatId).notifier);
    controller.submit('nothing');
    await settle();
    expect(stateOf(container).hasHits, isTrue);

    controller.clear();

    expect(stateOf(container), const InChatSearchState());
  });

  test('a search with no matches says so rather than looking broken', () async {
    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('absent');
    await settle();

    expect(stateOf(container).hasQuery, isTrue);
    expect(stateOf(container).hasHits, isFalse);
    expect(stateOf(container).isSearching, isFalse);
  });
}
