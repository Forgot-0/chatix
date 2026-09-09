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
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatsUseCase extends Mock implements GetChatsUseCase {}

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

/// Skips the real session bootstrap (secure storage + `GET /users/me/`) and
/// just reports who is signed in.
class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

void main() {
  const myUserId = 7;
  const strangerId = 99;
  const existingChatId = 'a3f1c2d4-0000-4000-8000-000000000001';
  const newChatId = 'b4e2d3c5-0000-4000-8000-000000000002';

  const me = UserEntity(id: myUserId, username: 'me', email: 'me@example.com');

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
  });

  ChatEntity chat(String id, {int memberCount = 3}) => ChatEntity(
    id: id,
    seqCounter: 5,
    lastActivityAt: DateTime.utc(2026, 1, 1),
    type: ChatType.group,
    name: 'Chat $id',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: memberCount,
    unreadCount: 0,
  );

  late MockGetChatsUseCase getChats;
  late MockGetChatUseCase getChat;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChats = MockGetChatsUseCase();
    getChat = MockGetChatUseCase();
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

  /// Builds the list with [initial] already loaded and the socket connected.
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
        getChatUseCaseProvider.overrideWithValue(getChat),
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

  Map<String, dynamic> memberJoined({
    required String chatId,
    required int userId,
    String eventId = 'evt-join-1',
  }) => {
    'type': 'member_joined',
    'channel': chatId,
    'payload': {
      'event_id': eventId,
      'event_name': 'chats.member.joined',
      'event': {'user_id': userId, 'role_id': 5},
      'message': null,
    },
    'ts': '2026-01-15T10:30:00Z',
  };

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('member_joined naming ME (api-docs §6.4)', () {
    test(
      'fetches and inserts a chat I was added to but do not have yet',
      () async {
        final container = await boot([chat(existingChatId)]);

        when(
          () => getChat.execute(newChatId),
        ).thenAnswer((_) async => Right(chat(newChatId)));

        channel.emit(memberJoined(chatId: newChatId, userId: myUserId));
        await settle();
        await settle();

        final ids = container
            .read(chatListProvider)
            .value!
            .items
            .map((c) => c.id);

        // `chat_created` only fires for a brand-new chat; being added to an
        // existing one arrives solely as `member_joined`.
        expect(ids, contains(newChatId));
        verify(() => getChat.execute(newChatId)).called(1);
      },
    );

    test(
      'drops the chat when the fetch says I have no access after all',
      () async {
        final container = await boot([chat(existingChatId)]);

        when(() => getChat.execute(newChatId)).thenAnswer(
          (_) async => const Left(
            ApiFailure(
              code: 'NOT_CHAT_MEMBER',
              message: 'Not a member',
              detail: <String, dynamic>{},
              status: 403,
            ),
          ),
        );

        channel.emit(memberJoined(chatId: newChatId, userId: myUserId));
        await settle();
        await settle();

        final ids = container
            .read(chatListProvider)
            .value!
            .items
            .map((c) => c.id);

        expect(ids, isNot(contains(newChatId)));
        expect(ids, contains(existingChatId));
      },
    );
  });

  group('member_joined naming SOMEONE ELSE', () {
    test('only bumps the member count, never refetches the row', () async {
      final container = await boot([chat(existingChatId, memberCount: 3)]);

      channel.emit(memberJoined(chatId: existingChatId, userId: strangerId));
      await settle();
      await settle();

      final row = container
          .read(chatListProvider)
          .value!
          .items
          .firstWhere((c) => c.id == existingChatId);

      expect(row.memberCount, 4);
      verifyNever(() => getChat.execute(any()));
    });
  });
}
