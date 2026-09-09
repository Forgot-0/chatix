import 'dart:convert';

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

/// `ws.history` is paged: `has_more` says a gap is still open and
/// `next_last_seq` is where to resume (api-docs §6.4). The catch-up is driven
/// by re-subscribing with that cursor, so the outbound frames are the contract.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  final chat = ChatEntity(
    id: chatId,
    seqCounter: 10,
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
    channel.outbound.sent.clear();

    return container;
  }

  Map<String, dynamic> history({
    required bool hasMore,
    int? nextLastSeq,
    int afterSeq = 10,
  }) => {
    'type': 'ws.history',
    'chat_id': chatId,
    'payload': {
      'after_seq': afterSeq,
      'messages': <dynamic>[],
      'has_more': hasMore,
      'next_last_seq': nextLastSeq,
    },
    'ts': '2026-01-15T10:30:00Z',
  };

  List<int> subscribeCursors() => [
    for (final frame in channel.outbound.sent)
      if (jsonDecode(frame! as String) case {
        'op': 'subscribe',
        'last_seq': final int seq,
      })
        seq,
  ];

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('has_more asks for the next slice with next_last_seq', () async {
    await boot();

    channel.emit(history(hasMore: true, nextLastSeq: 25));
    await settle();

    expect(subscribeCursors(), [25]);
  });

  test('walks page after page until the server says it is done', () async {
    await boot();

    channel.emit(history(hasMore: true, nextLastSeq: 25));
    await settle();
    channel.emit(history(hasMore: true, nextLastSeq: 40, afterSeq: 25));
    await settle();
    channel.emit(history(hasMore: false, nextLastSeq: 55, afterSeq: 40));
    await settle();

    // The last page closes the gap, so it must not ask for more.
    expect(subscribeCursors(), [25, 40]);
  });

  test('a final page alone asks for nothing', () async {
    await boot();

    channel.emit(history(hasMore: false, nextLastSeq: 25));
    await settle();

    expect(subscribeCursors(), isEmpty);
  });

  test('has_more without a cursor is ignored rather than looping', () async {
    await boot();

    channel.emit(history(hasMore: true, nextLastSeq: null));
    await settle();

    expect(subscribeCursors(), isEmpty);
  });

  test('a non-advancing cursor cannot spin the catch-up forever', () async {
    await boot();

    // A server that keeps answering with the same seq would otherwise pin the
    // client in an endless subscribe/history loop.
    for (var i = 0; i < 5; i++) {
      channel.emit(history(hasMore: true, nextLastSeq: 25));
      await settle();
    }

    expect(subscribeCursors(), [25]);
  });

  test('a cursor that goes backwards is refused too', () async {
    await boot();

    channel.emit(history(hasMore: true, nextLastSeq: 25));
    await settle();
    channel.emit(history(hasMore: true, nextLastSeq: 12));
    await settle();

    expect(subscribeCursors(), [25]);
  });

  test('the walk is capped so a broken server cannot pin the client', () async {
    await boot();

    for (var seq = 1; seq <= 40; seq++) {
      channel.emit(history(hasMore: true, nextLastSeq: seq));
      await settle();
    }

    // 20 pages is the cap in ChatDetailController.
    expect(subscribeCursors().length, lessThanOrEqualTo(20));
  });
}
