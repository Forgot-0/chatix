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
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatsUseCase extends Mock implements GetChatsUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// The chat list from the cache first, the network second — and the two
/// lists, main and archive, kept apart (api-docs §5.2).
void main() {
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  Map<String, dynamic> row(String id, {String name = 'Team'}) => {
    'id': id,
    'seq_counter': 10,
    'last_activity_at': '2026-01-01T00:00:00Z',
    'type': 'group',
    'name': name,
    'description': null,
    'avatar_s3_key': null,
    'is_public': false,
    'admin_only': false,
    'slow_mode_seconds': 0,
    'permissions': <String, bool>{},
    'created_by': 1,
    'member_count': 3,
    'unread_count': 2,
  };

  ChatEntity chat(String id, {String name = 'Fetched'}) => ChatEntity(
    id: id,
    seqCounter: 10,
    lastActivityAt: DateTime.utc(2026, 1, 1),
    type: ChatType.group,
    name: name,
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

  late ChatLocalStore store;
  late MockGetChatsUseCase getChats;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    store = inMemoryChatLocalStore();
    getChats = MockGetChatsUseCase();
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

  void answerChats(Future<Either<Failure, ChatsPage>> Function() answer) {
    when(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    ).thenAnswer((_) => answer());
  }

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [
        chatLocalDataSourceProvider.overrideWithValue(store),
        getChatsUseCaseProvider.overrideWithValue(getChats),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => FakeAuthController(me)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(chatListProvider, (_, _) {});
    return container;
  }

  Future<void> fillCache({bool archived = false}) => store.writeChatList(
    CachedChatList(
      chats: [row('c1', name: 'Cached')],
      hasNext: true,
      nextDate: '2026-01-01T00:00:00Z',
      nextChatId: 'c1',
      savedAt: DateTime.utc(2026),
    ),
    archived: archived,
  );

  test('the cached list is up before the fetch answers', () async {
    await fillCache();

    final stuck = Completer<Either<Failure, ChatsPage>>();
    answerChats(() => stuck.future);

    final container = boot();
    await container.read(authProvider.future);
    final state = await container.read(chatListProvider.future);

    expect(state.items.single.name, 'Cached');
    expect(state.items.single.unreadCount, 2);
    expect(state.nextChatId, 'c1', reason: 'the cursor is cached with it');
  });

  test('the fetched list replaces it, cursor and all', () async {
    await fillCache();
    answerChats(
      () async => Right(
        ChatsPage(
          chats: [chat('c2')],
          hasNext: true,
          nextDate: '2026-02-02T00:00:00Z',
          nextChatId: 'c2',
        ),
      ),
    );

    final container = boot();
    await container.read(authProvider.future);
    await container.read(chatListProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatListProvider).value!;
    expect(state.items.single.id, 'c2');
    expect(state.nextChatId, 'c2');
  });

  test('a failed fetch leaves the cached list alone', () async {
    // Being offline with yesterday's chat list is a working app.
    await fillCache();
    answerChats(() async => const Left(NetworkFailure()));

    final container = boot();
    await container.read(authProvider.future);
    await container.read(chatListProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(chatListProvider).hasError, isFalse);
    expect(container.read(chatListProvider).value!.items.single.name, 'Cached');
  });

  test('the main list does not open from the archive cache', () async {
    await fillCache(archived: true);
    answerChats(
      () async => const Right(
        ChatsPage(chats: [], hasNext: false, nextDate: null, nextChatId: null),
      ),
    );

    final container = boot();
    await container.read(authProvider.future);
    final state = await container.read(chatListProvider.future);

    expect(state.items, isEmpty);
  });
}
