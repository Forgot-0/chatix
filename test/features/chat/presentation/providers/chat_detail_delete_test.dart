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

/// `message_deleted` is a soft delete on the server (api-docs §5.4), but the
/// client has no tombstone to draw: the bubble renders a message or nothing.
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

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockMarkReadUseCase markRead;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
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
      (_) async => Right(
        MessagesPage(
          messages: [message(3), message(2), message(1)],
          nextCursor: null,
          hasNext: false,
        ),
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

  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
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

  Map<String, dynamic> deleted(String messageId) => {
    'type': 'message_deleted',
    'chat_id': chatId,
    'payload': {
      'event_id': 'e-$messageId',
      'event': {'message_id': messageId, 'deleted_by': 42},
    },
    'ts': '2026-01-15T10:30:00Z',
  };

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('the message leaves the window entirely', () async {
    final container = await boot();

    channel.emit(deleted('m2'));
    await settle();

    final state = container.read(chatDetailProvider(chatId)).value!;
    expect(state.messages.map((m) => m.id), ['m3', 'm1']);
  });

  test('no empty shell is left behind carrying a time and a menu', () async {
    final container = await boot();

    channel.emit(deleted('m2'));
    await settle();

    final state = container.read(chatDetailProvider(chatId)).value!;
    expect(state.messages.where((m) => m.id == 'm2'), isEmpty);
  });

  test('a reply banner pointing at it is cleared too', () async {
    final container = await boot();
    final notifier = container.read(chatDetailProvider(chatId).notifier);

    notifier.setReplyTo(message(2));
    channel.emit(deleted('m2'));
    await settle();

    expect(container.read(chatDetailProvider(chatId)).value!.replyTo, isNull);
  });

  test('deleting something not loaded changes nothing', () async {
    final container = await boot();

    channel.emit(deleted('m99'));
    await settle();

    final state = container.read(chatDetailProvider(chatId)).value!;
    expect(state.messages.map((m) => m.id), ['m3', 'm2', 'm1']);
  });
}
