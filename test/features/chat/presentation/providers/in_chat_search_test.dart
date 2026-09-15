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
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/repositories/message_search_repository.dart';
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

class MockMessageSearchRepository extends Mock
    implements MessageSearchRepository {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

/// Searching inside one chat is `GET /chats/messages/search/?chat_id=`
/// (api-docs §5.4.1), so it reaches history this device never loaded — and
/// opening a match is a second request, the window around it.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';

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

  MessageEntity message(int seq, String content) => MessageEntity(
    id: 'm-$seq',
    chatId: chatId,
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

  MessageSearchHit hit(int seq) =>
      MessageSearchHit.of(message(seq, 'ship it'), 'ship')!;

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockGetMessagesContextUseCase getContext;
  late MockMarkReadUseCase markRead;
  late MockMessageSearchRepository search;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    getContext = MockGetMessagesContextUseCase();
    markRead = MockMarkReadUseCase();
    search = MockMessageSearchRepository();
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
          messages: [message(20, 'nothing to see')],
          nextCursor: null,
          hasNext: false,
        ),
      ),
    );
    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => getContext.execute(any(), any(), limit: any(named: 'limit')),
    ).thenAnswer(
      (invocation) async => Right(
        MessagesPage(
          messages: [
            message(invocation.positionalArguments[1] as int, 'ship it'),
          ],
          nextCursor: null,
          hasNext: false,
        ),
      ),
    );
  });

  /// Scripts what the search answers with.
  void answerWith(
    List<MessageSearchHit> hits, {
    bool hasNext = false,
    String? nextMessageId,
    MessageSearchSource source = MessageSearchSource.server,
  }) {
    when(
      () => search.search(
        any(),
        chatId: any(named: 'chatId'),
        limit: any(named: 'limit'),
        lastMessageId: any(named: 'lastMessageId'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (_) async => Right(
        MessageSearchResult(
          hits: hits,
          source: source,
          hasNext: hasNext,
          nextMessageId: nextMessageId,
        ),
      ),
    );
  }

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
        messageSearchRepositoryProvider.overrideWithValue(search),
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

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  InChatSearchState stateOf(ProviderContainer container) =>
      container.read(inChatSearchProvider(chatId));

  test('the search is narrowed to this chat', () async {
    answerWith([hit(9)]);
    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('ship');
    await settle();

    verify(
      () => search.search(
        'ship',
        chatId: chatId,
        limit: any(named: 'limit'),
        lastMessageId: null,
        cancellation: any(named: 'cancellation'),
      ),
    ).called(1);
    expect(stateOf(container).hits, hasLength(1));
  });

  test('a query shorter than the server takes is never sent', () async {
    answerWith([hit(9)]);
    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('s');
    await settle();

    verifyNever(
      () => search.search(
        any(),
        chatId: any(named: 'chatId'),
        limit: any(named: 'limit'),
        lastMessageId: any(named: 'lastMessageId'),
        cancellation: any(named: 'cancellation'),
      ),
    );
    expect(stateOf(container).hits, isEmpty);
  });

  test('the newest match is opened, which is a context request', () async {
    answerWith([hit(9), hit(4)]);
    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('ship');
    await settle();

    expect(stateOf(container).position, 1);
    verify(
      () => getContext.execute(chatId, 9, limit: any(named: 'limit')),
    ).called(1);
  });

  test('the arrows walk the matches and take the chat with them', () async {
    answerWith([hit(9), hit(4)]);
    final container = await boot();

    final controller = container.read(inChatSearchProvider(chatId).notifier);
    controller.submit('ship');
    await settle();

    expect(stateOf(container).canGoNewer, isFalse);
    expect(stateOf(container).canGoOlder, isTrue);

    await controller.goOlder();

    expect(stateOf(container).position, 2);
    expect(stateOf(container).canGoOlder, isFalse);
    verify(
      () => getContext.execute(chatId, 4, limit: any(named: 'limit')),
    ).called(1);

    await controller.goNewer();
    expect(stateOf(container).position, 1);
  });

  test('walking past the page in hand fetches the one behind it', () async {
    answerWith([hit(9)], hasNext: true, nextMessageId: 'm-9');
    final container = await boot();

    final controller = container.read(inChatSearchProvider(chatId).notifier);
    controller.submit('ship');
    await settle();

    expect(stateOf(container).canGoOlder, isTrue);

    answerWith([hit(4)]);
    await controller.goOlder();

    expect(stateOf(container).hits.map((h) => h.seq), [9, 4]);
    expect(stateOf(container).position, 2);
    expect(stateOf(container).canGoOlder, isFalse);
  });

  test('the arrows stop at the ends instead of wrapping around', () async {
    answerWith([hit(4)]);
    final container = await boot();

    final controller = container.read(inChatSearchProvider(chatId).notifier);
    controller.submit('ship');
    await settle();

    await controller.goNewer();
    await controller.goOlder();

    expect(stateOf(container).index, 0);
  });

  test('a match already on screen needs no request', () async {
    answerWith([MessageSearchHit.of(message(20, 'nothing to see'), 'nothing')!]);
    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('nothing');
    await settle();

    verifyNever(
      () => getContext.execute(any(), any(), limit: any(named: 'limit')),
    );
  });

  test('typing waits for the typing to stop', () async {
    answerWith([hit(9)]);
    final container = await boot();
    final controller = container.read(inChatSearchProvider(chatId).notifier);

    controller.type('ship');
    expect(stateOf(container).isSearching, isTrue);
    expect(stateOf(container).hits, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 320));

    expect(stateOf(container).hits, hasLength(1));
    expect(stateOf(container).isSearching, isFalse);
  });

  test('an answer from the device says so', () async {
    answerWith([hit(9)], source: MessageSearchSource.localCache);
    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('ship');
    await settle();

    expect(stateOf(container).isLocal, isTrue);
  });

  test('clearing puts everything back', () async {
    answerWith([hit(9)]);
    final container = await boot();

    final controller = container.read(inChatSearchProvider(chatId).notifier);
    controller.submit('ship');
    await settle();
    expect(stateOf(container).hasHits, isTrue);

    controller.clear();

    expect(stateOf(container), const InChatSearchState());
  });

  test('a search with no matches says so rather than looking broken', () async {
    answerWith(const []);
    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('absent');
    await settle();

    expect(stateOf(container).hasQuery, isTrue);
    expect(stateOf(container).hasHits, isFalse);
    expect(stateOf(container).isSearching, isFalse);
  });

  test('a search that fails leaves the bar empty, not stuck', () async {
    when(
      () => search.search(
        any(),
        chatId: any(named: 'chatId'),
        limit: any(named: 'limit'),
        lastMessageId: any(named: 'lastMessageId'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure()));

    final container = await boot();

    container.read(inChatSearchProvider(chatId).notifier).submit('ship');
    await settle();

    expect(stateOf(container).isSearching, isFalse);
    expect(stateOf(container).hasHits, isFalse);
  });
}
