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
import 'package:chatix/features/chat/domain/usecases/get_message_use_case.dart';
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

class MockGetMessageUseCase extends Mock implements GetMessageUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// Jump-to-message rests on `GET /messages/context/`, the endpoint that returns
/// the slice AROUND a seq (api-docs §5.4).
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  MessageEntity message(String id, int seq) => MessageEntity(
    id: id,
    chatId: chatId,
    seq: seq,
    authorId: 7,
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

  // The live tail: newest first, as `GET /messages/` returns it.
  final tail = [message('m100', 100), message('m99', 99)];

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockGetMessagesContextUseCase getContext;
  late MockGetMessageUseCase getMessage;
  late MockMarkReadUseCase markRead;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    getContext = MockGetMessagesContextUseCase();
    getMessage = MockGetMessageUseCase();
    markRead = MockMarkReadUseCase();
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
      (_) async =>
          Right(MessagesPage(messages: tail, nextCursor: 99, hasNext: true)),
    );
    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));
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
        getMessageUseCaseProvider.overrideWithValue(getMessage),
        markReadUseCaseProvider.overrideWithValue(markRead),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => FakeAuthController(me)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.listen(chatDetailProvider(chatId), (_, _) {});
    await container.read(chatDetailProvider(chatId).future);
    await socket.connect();

    return container;
  }

  group('revealMessage — already in the window', () {
    test('highlights without touching the network', () async {
      final container = await boot();

      final ok = await container
          .read(chatDetailProvider(chatId).notifier)
          .revealMessage('m99');

      expect(ok, isTrue);
      final state = container.read(chatDetailProvider(chatId)).value!;
      expect(state.highlightMessageId, 'm99');
      expect(state.isViewingHistory, isFalse);
      verifyNever(
        () => getContext.execute(any(), any(), limit: any(named: 'limit')),
      );
      verifyNever(() => getMessage.execute(any(), any()));
    });
  });

  group('revealMessage — outside the window', () {
    test('loads the context slice around the target seq', () async {
      final container = await boot();

      final slice = [
        message('m12', 12),
        message('m11', 11),
        message('m10', 10),
      ];
      when(
        () => getContext.execute(chatId, 11, limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async =>
            Right(MessagesPage(messages: slice, nextCursor: 10, hasNext: true)),
      );

      final ok = await container
          .read(chatDetailProvider(chatId).notifier)
          .revealMessage('m11', seq: 11);

      expect(ok, isTrue);
      final state = container.read(chatDetailProvider(chatId)).value!;

      // The slice REPLACES the tail: splicing it in would leave an invisible
      // gap between seq 12 and seq 99 and make backward paging lie.
      expect(state.messages.map((m) => m.id), ['m12', 'm11', 'm10']);
      expect(state.nextCursor, 10);
      expect(state.highlightMessageId, 'm11');
      expect(state.isViewingHistory, isTrue);
    });

    test(
      'resolves the seq via GET /messages/{id}/ when none was supplied',
      () async {
        final container = await boot();

        when(
          () => getMessage.execute(chatId, 'm11'),
        ).thenAnswer((_) async => Right(message('m11', 11)));
        when(
          () => getContext.execute(chatId, 11, limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => Right(
            MessagesPage(
              messages: [message('m11', 11)],
              nextCursor: null,
              hasNext: false,
            ),
          ),
        );

        final ok = await container
            .read(chatDetailProvider(chatId).notifier)
            .revealMessage('m11');

        expect(ok, isTrue);
        verify(() => getMessage.execute(chatId, 'm11')).called(1);
      },
    );

    test(
      'reports failure and keeps the window when the context call fails',
      () async {
        final container = await boot();

        when(
          () => getContext.execute(chatId, 11, limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => const Left(
            ApiFailure(
              code: 'NOT_FOUND_MESSAGE',
              message: 'gone',
              detail: <String, dynamic>{},
              status: 404,
            ),
          ),
        );

        final ok = await container
            .read(chatDetailProvider(chatId).notifier)
            .revealMessage('m11', seq: 11);

        expect(ok, isFalse);
        final state = container.read(chatDetailProvider(chatId)).value!;
        expect(state.messages.map((m) => m.id), ['m100', 'm99']);
        expect(state.isViewingHistory, isFalse);
        expect(state.highlightMessageId, isNull);
      },
    );

    test(
      'reports failure when the slice does not actually contain the target',
      () async {
        final container = await boot();

        when(
          () => getContext.execute(chatId, 11, limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => Right(
            MessagesPage(
              messages: [message('m12', 12)],
              nextCursor: null,
              hasNext: false,
            ),
          ),
        );

        final ok = await container
            .read(chatDetailProvider(chatId).notifier)
            .revealMessage('m11', seq: 11);

        expect(ok, isFalse);
        expect(
          container.read(chatDetailProvider(chatId)).value!.isViewingHistory,
          isFalse,
        );
      },
    );

    test('gives up when the seq cannot be resolved at all', () async {
      final container = await boot();

      when(() => getMessage.execute(chatId, 'nope')).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'NOT_FOUND_MESSAGE',
            message: 'gone',
            detail: <String, dynamic>{},
            status: 404,
          ),
        ),
      );

      final ok = await container
          .read(chatDetailProvider(chatId).notifier)
          .revealMessage('nope');

      expect(ok, isFalse);
      verifyNever(
        () => getContext.execute(any(), any(), limit: any(named: 'limit')),
      );
    });
  });

  // The deep-link path: `/chats/{id}?message={seq}` already names the seq, so
  // there is nothing to resolve before calling the context endpoint.
  group('revealSeq', () {
    test('highlights a loaded seq without touching the network', () async {
      final container = await boot();

      final ok = await container
          .read(chatDetailProvider(chatId).notifier)
          .revealSeq(99);

      expect(ok, isTrue);
      final state = container.read(chatDetailProvider(chatId)).value!;
      expect(state.highlightMessageId, 'm99');
      expect(state.isViewingHistory, isFalse);
      verifyNever(
        () => getContext.execute(any(), any(), limit: any(named: 'limit')),
      );
      verifyNever(() => getMessage.execute(any(), any()));
    });

    test('loads the context slice and never looks the id up first', () async {
      final container = await boot();

      final slice = [
        message('m12', 12),
        message('m11', 11),
        message('m10', 10),
      ];
      when(
        () => getContext.execute(chatId, 11, limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async =>
            Right(MessagesPage(messages: slice, nextCursor: 10, hasNext: true)),
      );

      final ok = await container
          .read(chatDetailProvider(chatId).notifier)
          .revealSeq(11);

      expect(ok, isTrue);
      final state = container.read(chatDetailProvider(chatId)).value!;
      expect(state.messages.map((m) => m.id), ['m12', 'm11', 'm10']);
      expect(state.nextCursor, 10);
      expect(state.highlightMessageId, 'm11');
      expect(state.isViewingHistory, isTrue);
      verifyNever(() => getMessage.execute(any(), any()));
    });

    test('reports failure and keeps the window when the call fails', () async {
      final container = await boot();

      when(
        () => getContext.execute(chatId, 11, limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'NOT_FOUND_MESSAGE',
            message: 'gone',
            detail: <String, dynamic>{},
            status: 404,
          ),
        ),
      );

      final ok = await container
          .read(chatDetailProvider(chatId).notifier)
          .revealSeq(11);

      expect(ok, isFalse);
      final state = container.read(chatDetailProvider(chatId)).value!;
      expect(state.messages.map((m) => m.id), ['m100', 'm99']);
      expect(state.isViewingHistory, isFalse);
      expect(state.highlightMessageId, isNull);
    });

    test('reports failure when the slice misses the seq it asked for', () async {
      final container = await boot();

      when(
        () => getContext.execute(chatId, 11, limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => Right(
          MessagesPage(
            messages: [message('m12', 12)],
            nextCursor: null,
            hasNext: false,
          ),
        ),
      );

      final ok = await container
          .read(chatDetailProvider(chatId).notifier)
          .revealSeq(11);

      expect(ok, isFalse);
      expect(
        container.read(chatDetailProvider(chatId)).value!.isViewingHistory,
        isFalse,
      );
    });
  });

  group('clearHighlight', () {
    test('drops the flash once the view has consumed it', () async {
      final container = await boot();
      final notifier = container.read(chatDetailProvider(chatId).notifier);

      await notifier.revealMessage('m99');
      expect(
        container.read(chatDetailProvider(chatId)).value!.highlightMessageId,
        'm99',
      );

      notifier.clearHighlight();
      expect(
        container.read(chatDetailProvider(chatId)).value!.highlightMessageId,
        isNull,
      );
    });
  });
}
