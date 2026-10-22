import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_local_chats_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/direct_chat_opener.dart';

class _MockGetChats extends Mock implements GetChatsUseCase {}

class _MockCreateChat extends Mock implements CreateChatUseCase {}

class _MockLocalChats extends Mock implements GetLocalChatsUseCase {}

class _FakeAuth extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: me, username: 'me', email: 'me@example.com');
}

class _FakeChatList extends ChatListController {
  _FakeChatList(this._state, {super.isArchive});

  final ChatListState _state;
  int refreshes = 0;

  @override
  Future<ChatListState> build() async => _state;

  @override
  Future<void> refresh() async => refreshes++;
}

const int me = 7;

ChatEntity direct(String id, int peer) => ChatEntity(
  id: id,
  seqCounter: 1,
  lastActivityAt: DateTime.utc(2026, 10, 1),
  type: ChatType.direct,
  name: null,
  description: null,
  avatarS3Key: null,
  isPublic: false,
  adminOnly: false,
  slowModeSeconds: 0,
  permissions: const {},
  createdBy: me,
  memberCount: 2,
  peer: ChatProfileEntity(
    userId: peer,
    username: 'user$peer',
    displayName: 'User $peer',
    avatarUrl: null,
    avatarS3Key: null,
  ),
);

ChatsPage page(List<ChatEntity> chats, {String? next}) => ChatsPage(
  chats: chats,
  hasNext: next != null,
  nextDate: next == null ? null : '2026-09-01T00:00:00Z',
  nextChatId: next,
);

/// "Нельзя создать два директа": the 1:1 chat with a person is looked for
/// everywhere it could be before one is made, and two taps make one.
void main() {
  late _MockGetChats getChats;
  late _MockCreateChat createChat;
  late _MockLocalChats localChats;
  late _FakeChatList mainList;

  setUpAll(() {
    registerFallbackValue(ChatType.direct);
    registerFallbackValue(page(const []));
  });

  setUp(() {
    getChats = _MockGetChats();
    createChat = _MockCreateChat();
    localChats = _MockLocalChats();
    when(
      () => localChats.execute(archived: any(named: 'archived')),
    ).thenReturn(null);
    // Unless a test says otherwise, the server has nothing anywhere.
    when(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    ).thenAnswer((_) async => Right(page(const [])));
  });

  void answerCreate(Future<Either<Failure, ChatEntity>> Function() answer) {
    when(
      () => createChat.execute(
        name: any(named: 'name'),
        description: any(named: 'description'),
        chatType: any(named: 'chatType'),
        memberIds: any(named: 'memberIds'),
        isPublic: any(named: 'isPublic'),
        adminOnly: any(named: 'adminOnly'),
        slowModeSeconds: any(named: 'slowModeSeconds'),
        permissions: any(named: 'permissions'),
      ),
    ).thenAnswer((_) => answer());
  }

  void verifyCreated(int times) {
    verify(
      () => createChat.execute(
        name: any(named: 'name'),
        description: any(named: 'description'),
        chatType: ChatType.direct,
        memberIds: any(named: 'memberIds'),
        isPublic: any(named: 'isPublic'),
        adminOnly: any(named: 'adminOnly'),
        slowModeSeconds: any(named: 'slowModeSeconds'),
        permissions: any(named: 'permissions'),
      ),
    ).called(times);
  }

  void verifyNothingCreated() {
    verifyNever(
      () => createChat.execute(
        name: any(named: 'name'),
        description: any(named: 'description'),
        chatType: any(named: 'chatType'),
        memberIds: any(named: 'memberIds'),
        isPublic: any(named: 'isPublic'),
        adminOnly: any(named: 'adminOnly'),
        slowModeSeconds: any(named: 'slowModeSeconds'),
        permissions: any(named: 'permissions'),
      ),
    );
  }

  Future<ProviderContainer> containerWith({
    ChatListState main = const ChatListState(),
    ChatListState? archive,
  }) async {
    mainList = _FakeChatList(main);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: <Override>[
        authProvider.overrideWith(_FakeAuth.new),
        chatListProvider.overrideWith(() => mainList),
        archivedChatListProvider.overrideWith(
          () =>
              _FakeChatList(archive ?? const ChatListState(), isArchive: true),
        ),
        getChatsUseCaseProvider.overrideWithValue(getChats),
        createChatUseCaseProvider.overrideWithValue(createChat),
        getLocalChatsUseCaseProvider.overrideWithValue(localChats),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(chatListProvider.future);
    if (archive != null) await container.read(archivedChatListProvider.future);
    return container;
  }

  test('a chat on screen opens without a single request', () async {
    final container = await containerWith(
      main: ChatListState(items: [direct('chat-ann', 9)]),
    );

    final result = await container.read(directChatOpenerProvider).resolve(9);

    expect(result, const Right<Failure, String>('chat-ann'));
    verifyNever(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    );
    verifyNothingCreated();
  });

  test(
    'an archived chat is found even when the archive was never opened',
    () async {
      when(
        () => getChats.execute(limit: any(named: 'limit'), archived: true),
      ).thenAnswer((_) async => Right(page([direct('chat-archived', 9)])));
      final container = await containerWith(
        main: ChatListState(items: [direct('chat-bob', 10)]),
      );

      final result = await container.read(directChatOpenerProvider).resolve(9);

      expect(result, const Right<Failure, String>('chat-archived'));
      verifyNothingCreated();
    },
  );

  test('a chat further down than the loaded pages is found', () async {
    when(
      () => getChats.executeNextPage(
        any(),
        limit: any(named: 'limit'),
        archived: false,
      ),
    ).thenAnswer((_) async => Right(page([direct('chat-old', 9)])));
    final container = await containerWith(
      main: ChatListState(
        items: [direct('chat-bob', 10)],
        hasNext: true,
        nextDate: '2026-09-01T00:00:00Z',
        nextChatId: 'chat-bob',
      ),
    );

    final result = await container.read(directChatOpenerProvider).resolve(9);

    expect(result, const Right<Failure, String>('chat-old'));
    // It resumed from the loaded pages' cursor, not from the top.
    final asked =
        verify(
              () => getChats.executeNextPage(
                captureAny(),
                limit: GetChatsUseCase.maxLimit,
                archived: false,
              ),
            ).captured.single
            as ChatsPage;
    expect(asked.nextChatId, 'chat-bob');
    verifyNothingCreated();
  });

  test("the device's saved archive counts without asking the server", () async {
    when(
      () => localChats.execute(archived: true),
    ).thenReturn(page([direct('chat-saved', 9)]));
    final container = await containerWith();

    final result = await container.read(directChatOpenerProvider).resolve(9);

    expect(result, const Right<Failure, String>('chat-saved'));
    verifyNever(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    );
    verifyNothingCreated();
  });

  test(
    'nobody anywhere: one chat is made, and a second tap reuses it',
    () async {
      answerCreate(() async => Right(direct('chat-new', 9)));
      final container = await containerWith();
      final opener = container.read(directChatOpenerProvider);

      final first = await opener.resolve(9);
      // The list has not caught up yet — the opener remembers.
      final second = await opener.resolve(9);

      expect(first, const Right<Failure, String>('chat-new'));
      expect(second, const Right<Failure, String>('chat-new'));
      verifyCreated(1);
      expect(mainList.refreshes, 1);
    },
  );

  test('two taps at once share one lookup and make one chat', () async {
    final gate = Completer<Either<Failure, ChatEntity>>();
    answerCreate(() => gate.future);
    final container = await containerWith();
    final opener = container.read(directChatOpenerProvider);

    final first = opener.resolve(9);
    final second = opener.resolve(9);
    gate.complete(Right(direct('chat-new', 9)));

    expect(await first, const Right<Failure, String>('chat-new'));
    expect(await second, const Right<Failure, String>('chat-new'));
    verifyCreated(1);
  });

  test('when the lists cannot be read, nothing is created', () async {
    when(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    ).thenAnswer((_) async => const Left(NetworkFailure()));
    final container = await containerWith();

    final result = await container.read(directChatOpenerProvider).resolve(9);

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    verifyNothingCreated();
  });

  test('a list on screen in full is not read again', () async {
    answerCreate(() async => Right(direct('chat-new', 9)));
    final container = await containerWith(
      main: ChatListState(items: [direct('chat-bob', 10)]),
      archive: ChatListState(items: [direct('chat-zed', 11)]),
    );

    final result = await container.read(directChatOpenerProvider).resolve(9);

    expect(result, const Right<Failure, String>('chat-new'));
    verifyNever(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    );
    verifyCreated(1);
  });

  test('DIRECT_CHAT_EXISTS, should it ever come, lands in that chat', () async {
    answerCreate(
      () async => const Left(
        ApiFailure(
          code: 'DIRECT_CHAT_EXISTS',
          message: 'exists',
          detail: {'chat_id': 'chat-server'},
          status: 409,
        ),
      ),
    );
    final container = await containerWith();

    final result = await container.read(directChatOpenerProvider).resolve(9);

    expect(result, const Right<Failure, String>('chat-server'));
  });

  test("another person's chat is not mistaken for this one", () async {
    answerCreate(() async => Right(direct('chat-new', 9)));
    final container = await containerWith(
      main: ChatListState(items: [direct('chat-bob', 10)]),
    );

    final result = await container.read(directChatOpenerProvider).resolve(9);

    expect(result, const Right<Failure, String>('chat-new'));
    verifyCreated(1);
  });
}
