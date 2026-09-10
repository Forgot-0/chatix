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
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatsUseCase extends Mock implements GetChatsUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

void main() {
  const myUserId = 7;
  const peerId = 9;
  const chatId = 'a3f1c2d4-0000-4000-8000-000000000001';

  const me = UserEntity(id: myUserId, username: 'me', email: 'me@example.com');

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
  });

  MessageEntity lastMessage({required int seq, required int authorId}) =>
      MessageEntity(
        id: 'm-$seq',
        chatId: chatId,
        seq: seq,
        authorId: authorId,
        type: MessageType.text,
        content: 'hello',
        replyToId: null,
        forwardedFromChatId: null,
        forwardedFromMessageId: null,
        forwardedFromAuthorId: null,
        isEdited: false,
        createdAt: DateTime.utc(2026, 1, 1),
        profile: ChatProfileEntity(
          userId: authorId,
          username: 'someone',
          displayName: 'Someone',
          avatarUrl: null,
          avatarS3Key: null,
        ),
      );

  ChatEntity chat({int unread = 3, MessageEntity? last}) => ChatEntity(
    id: chatId,
    seqCounter: 12,
    lastActivityAt: DateTime.utc(2026, 1, 1),
    type: ChatType.direct,
    name: null,
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: myUserId,
    memberCount: 2,
    unreadCount: unread,
    lastMessage: last,
  );

  late MockGetChatsUseCase getChats;
  late MockMarkReadUseCase markRead;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChats = MockGetChatsUseCase();
    markRead = MockMarkReadUseCase();
    channel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => channel,
    );
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  Future<ProviderContainer> boot(List<ChatEntity> initial) async {
    when(() => getChats.execute(limit: any(named: 'limit'))).thenAnswer(
      (_) async => Right(
        ChatsPage(
          chats: initial,
          hasNext: false,
          nextDate: null,
          nextChatId: null,
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        getChatsUseCaseProvider.overrideWithValue(getChats),
        markReadUseCaseProvider.overrideWithValue(markRead),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => FakeAuthController(me)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(chatListProvider.future);
    await socket.connect();

    return container;
  }

  Map<String, dynamic> messagesRead({
    required int seq,
    required int readerId,
    String eventId = 'evt-read-1',
  }) => {
    'type': 'messages_read',
    'channel': chatId,
    'payload': {
      'event_id': eventId,
      'event_name': 'chats.messages.read',
      'event': {'seq': seq, 'reader_id': readerId},
      'message': null,
    },
    'ts': '2026-01-15T10:30:00Z',
  };

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  ChatListState stateOf(ProviderContainer container) =>
      container.read(chatListProvider).requireValue;

  group('markChatRead', () {
    test('clears the badge and reads up to the last message', () async {
      when(() => markRead.execute(any(), any())).thenAnswer(
        (_) async => const Right(null),
      );

      final container = await boot([
        chat(unread: 3, last: lastMessage(seq: 11, authorId: peerId)),
      ]);

      await container.read(chatListProvider.notifier).markChatRead(chatId);

      expect(stateOf(container).items.single.unreadCount, 0);
      verify(() => markRead.execute(chatId, 11)).called(1);
    });

    test('falls back to the chat seq counter without a preview', () async {
      when(() => markRead.execute(any(), any())).thenAnswer(
        (_) async => const Right(null),
      );

      final container = await boot([chat(unread: 2)]);
      await container.read(chatListProvider.notifier).markChatRead(chatId);

      verify(() => markRead.execute(chatId, 12)).called(1);
    });

    test('the badge comes back when the request does not land', () async {
      when(() => markRead.execute(any(), any())).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            message: 'nope',
            code: 'NOT_CHAT_MEMBER',
            detail: null,
            status: 403,
          ),
        ),
      );

      final container = await boot([
        chat(unread: 3, last: lastMessage(seq: 11, authorId: peerId)),
      ]);

      await container.read(chatListProvider.notifier).markChatRead(chatId);

      expect(stateOf(container).items.single.unreadCount, 3);
    });

    test('a chat with nothing unread is left alone', () async {
      final container = await boot([chat(unread: 0)]);

      await container.read(chatListProvider.notifier).markChatRead(chatId);

      verifyNever(() => markRead.execute(any(), any()));
    });
  });

  group('peer read position (api-docs §6.4)', () {
    test('a read by somebody else is remembered for the ticks', () async {
      final container = await boot([
        chat(unread: 0, last: lastMessage(seq: 11, authorId: myUserId)),
      ]);

      channel.emit(messagesRead(seq: 11, readerId: peerId));
      await settle();

      expect(stateOf(container).peerReadSeqOf(chatId), 11);
    });

    test('my own read clears the badge instead', () async {
      final container = await boot([
        chat(unread: 4, last: lastMessage(seq: 11, authorId: peerId)),
      ]);

      channel.emit(messagesRead(seq: 11, readerId: myUserId));
      await settle();

      expect(stateOf(container).items.single.unreadCount, 0);
      expect(stateOf(container).peerReadSeqOf(chatId), isNull);
    });

    test('the position never moves backwards', () async {
      final container = await boot([
        chat(unread: 0, last: lastMessage(seq: 11, authorId: myUserId)),
      ]);

      channel.emit(messagesRead(seq: 11, readerId: peerId));
      await settle();
      channel.emit(
        messagesRead(seq: 4, readerId: peerId, eventId: 'evt-read-2'),
      );
      await settle();

      expect(stateOf(container).peerReadSeqOf(chatId), 11);
    });
  });
}
