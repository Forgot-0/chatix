import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
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

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

class MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class MockGetMessagesContextUseCase extends Mock
    implements GetMessagesContextUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// Read state: what the client is allowed to tell the server it has read
/// (`POST /chats/{id}/messages/read/`, api-docs §5.4), and where the unread
/// divider is pinned while that happens.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  MessageEntity message(int seq) => MessageEntity(
    id: 'm$seq',
    chatId: chatId,
    seq: seq,
    authorId: 42,
    type: MessageType.text,
    content: 'message $seq',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 1, 1),
    attachments: const [],
  );

  ChatEntity chatWith({int? lastReadSeq, int unread = 0}) => ChatEntity(
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
    unreadCount: unread,
    lastRead: lastReadSeq == null
        ? null
        : ReadDetailEntity(
            lastReadMessageSeq: lastReadSeq,
            lastReadAt: DateTime.utc(2026, 1, 1),
          ),
  );

  final tail = [message(100), message(99), message(98)];

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockGetMessagesContextUseCase getContext;
  late MockMarkReadUseCase markRead;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    getContext = MockGetMessagesContextUseCase();
    markRead = MockMarkReadUseCase();
    channel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => channel,
    );

    when(
      () => getMessages.execute(chatId, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async =>
          Right(MessagesPage(messages: tail, nextCursor: 97, hasNext: true)),
    );
    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  Future<ProviderContainer> boot(ChatEntity chat) async {
    when(() => getChat.execute(chatId)).thenAnswer((_) async => Right(chat));

    final container = ProviderContainer(
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        getMessagesContextUseCaseProvider.overrideWithValue(getContext),
        markReadUseCaseProvider.overrideWithValue(markRead),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => FakeAuthController(me)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.listen(chatDetailProvider(chatId), (_, _) {});
    await container.read(chatDetailProvider(chatId).future);

    return container;
  }

  group('reporting', () {
    test('opening a chat reads nothing on its own', () async {
      // The feed reports what it has really put on screen. Marking the newest
      // message read just because it was fetched clears a badge for messages
      // nobody has looked at.
      await boot(chatWith(lastReadSeq: 90, unread: 10));

      verifyNever(() => markRead.execute(any(), any()));
    });

    test('the first report goes out at once', () async {
      final container = await boot(chatWith(lastReadSeq: 90, unread: 10));

      container.read(chatDetailProvider(chatId).notifier).reportRead(95);
      await Future<void>.delayed(Duration.zero);

      verify(() => markRead.execute(chatId, 95)).called(1);
    });

    test(
      'a burst collapses into one request and one trailing catch-up',
      () async {
        final container = await boot(chatWith(lastReadSeq: 90, unread: 10));
        final notifier = container.read(chatDetailProvider(chatId).notifier);

        for (final seq in [95, 96, 97, 98, 99, 100]) {
          notifier.reportRead(seq);
        }
        await Future<void>.delayed(Duration.zero);

        verify(() => markRead.execute(chatId, 95)).called(1);
        verifyNoMoreInteractions(markRead);

        await Future<void>.delayed(
          ChatDetailController.readThrottle + const Duration(milliseconds: 150),
        );

        // Only the furthest one: the seqs in between are implied by it.
        verify(() => markRead.execute(chatId, 100)).called(1);
        verifyNoMoreInteractions(markRead);
      },
    );

    test('going backwards is never reported', () async {
      final container = await boot(chatWith(lastReadSeq: 90, unread: 10));
      final notifier = container.read(chatDetailProvider(chatId).notifier);

      notifier.reportRead(99);
      await Future<void>.delayed(Duration.zero);
      verify(() => markRead.execute(chatId, 99)).called(1);

      // Scrolling back up over messages already reported.
      notifier.reportRead(95);
      await Future<void>.delayed(
        ChatDetailController.readThrottle + const Duration(milliseconds: 150),
      );

      verifyNoMoreInteractions(markRead);
    });
  });

  group('unread anchor', () {
    test('is taken from last_read.last_read_message_seq at open', () async {
      final container = await boot(chatWith(lastReadSeq: 90, unread: 10));

      final state = container.read(chatDetailProvider(chatId)).value!;
      expect(state.unreadAnchorSeq, 90);
      expect(state.unreadAtOpen, 10);
    });

    test('does not move when the chat is re-fetched mid-read', () async {
      final container = await boot(chatWith(lastReadSeq: 90, unread: 10));
      final notifier = container.read(chatDetailProvider(chatId).notifier);

      // The server now agrees everything is read — which is exactly when a
      // live cursor would drag the divider off the screen.
      when(
        () => getChat.execute(chatId),
      ).thenAnswer((_) async => Right(chatWith(lastReadSeq: 100)));

      await notifier.refresh();

      final state = container.read(chatDetailProvider(chatId)).value!;
      expect(state.unreadAnchorSeq, 90);
      expect(state.unreadAtOpen, 10);
    });

    test('a chat with nothing unread has no anchor to place', () async {
      final container = await boot(chatWith(lastReadSeq: 100));

      final state = container.read(chatDetailProvider(chatId)).value!;
      expect(state.unreadAtOpen, 0);
    });
  });

  group('loadUnreadWindow', () {
    test('pulls the window back when the boundary is off the top', () async {
      // Read stopped at seq 40, but the freshest page starts at 98: the
      // divider belongs to a slice that was never fetched.
      final container = await boot(chatWith(lastReadSeq: 40, unread: 60));

      final slice = [message(42), message(41), message(40)];
      when(
        () => getContext.execute(chatId, 40, limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async =>
            Right(MessagesPage(messages: slice, nextCursor: 39, hasNext: true)),
      );

      final pulled = await container
          .read(chatDetailProvider(chatId).notifier)
          .loadUnreadWindow();

      expect(pulled, isTrue);
      final state = container.read(chatDetailProvider(chatId)).value!;
      expect(state.messages.map((m) => m.seq), [42, 41, 40]);
      expect(state.nextCursor, 39);
      expect(state.isViewingHistory, isTrue);
      // The divider still belongs where reading stopped.
      expect(state.unreadAnchorSeq, 40);
    });

    test('does nothing when the window already covers the boundary', () async {
      final container = await boot(chatWith(lastReadSeq: 98, unread: 2));

      final pulled = await container
          .read(chatDetailProvider(chatId).notifier)
          .loadUnreadWindow();

      expect(pulled, isFalse);
      verifyNever(
        () => getContext.execute(any(), any(), limit: any(named: 'limit')),
      );
    });

    test('does nothing when there was nothing unread', () async {
      final container = await boot(chatWith(lastReadSeq: 10));

      final pulled = await container
          .read(chatDetailProvider(chatId).notifier)
          .loadUnreadWindow();

      expect(pulled, isFalse);
      verifyNever(
        () => getContext.execute(any(), any(), limit: any(named: 'limit')),
      );
    });
  });
}
