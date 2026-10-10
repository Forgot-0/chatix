import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class MockGetMembersUseCase extends Mock implements GetMembersUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

void main() {
  const myUserId = 7;
  const peerId = 9;
  const chatId = 'c1';

  const me = UserEntity(id: myUserId, username: 'me', email: 'me@example.com');

  late MockGetMembersUseCase getMembers;

  ChatMemberEntity member(int userId) => ChatMemberEntity(
    userId: userId,
    roleId: ChatRole.direct.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
  );

  MembersPage page({required bool peerOnline, bool includePeer = true}) =>
      MembersPage(
        members: [member(myUserId), if (includePeer) member(peerId)],
        hasNext: false,
        nextUserId: null,
        presence: [
          const MemberPresenceEntity(userId: myUserId, isOnline: true),
          if (includePeer)
            MemberPresenceEntity(userId: peerId, isOnline: peerOnline),
        ],
      );

  setUp(() {
    getMembers = MockGetMembersUseCase();
  });

  Future<ProviderContainer> boot({UserEntity? user = me}) async {
    final container = ProviderContainer(
      overrides: [
        getMembersUseCaseProvider.overrideWithValue(getMembers),
        authProvider.overrideWith(() => FakeAuthController(user)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    return container;
  }

  void answerWith(MembersPage value) {
    when(
      () => getMembers.execute(
        any(),
        limit: any(named: 'limit'),
        includePresence: any(named: 'includePresence'),
      ),
    ).thenAnswer((_) async => Right(value));
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('reports the other side, not me', () async {
    answerWith(page(peerOnline: true));
    final container = await boot();

    container.read(chatPresenceProvider.notifier).ensureFresh(chatId);
    await settle();

    expect(container.read(chatPeerOnlineProvider(chatId)), isTrue);
  });

  test('presence is asked for once, however many rows ask', () async {
    answerWith(page(peerOnline: false));
    final container = await boot();

    final controller = container.read(chatPresenceProvider.notifier);
    controller.ensureFresh(chatId);
    controller.ensureFresh(chatId);
    await settle();
    controller.ensureFresh(chatId);
    await settle();

    verify(
      () => getMembers.execute(
        chatId,
        limit: any(named: 'limit'),
        includePresence: true,
      ),
    ).called(1);
  });

  test('a refresh makes the next row ask again', () async {
    answerWith(page(peerOnline: false));
    final container = await boot();

    final controller = container.read(chatPresenceProvider.notifier);
    controller.ensureFresh(chatId);
    await settle();

    controller.invalidate();
    expect(container.read(chatPeerOnlineProvider(chatId)), isNull);

    answerWith(page(peerOnline: true));
    controller.ensureFresh(chatId);
    await settle();

    expect(container.read(chatPeerOnlineProvider(chatId)), isTrue);
  });

  test('a member with no presence entry counts as offline', () async {
    answerWith(
      MembersPage(
        members: [member(myUserId), member(peerId)],
        hasNext: false,
        nextUserId: null,
        presence: const [],
      ),
    );
    final container = await boot();

    container.read(chatPresenceProvider.notifier).ensureFresh(chatId);
    await settle();

    expect(container.read(chatPeerOnlineProvider(chatId)), isFalse);
  });

  test('a chat we cannot read stays unknown and is not retried', () async {
    when(
      () => getMembers.execute(
        any(),
        limit: any(named: 'limit'),
        includePresence: any(named: 'includePresence'),
      ),
    ).thenAnswer(
      (_) async => const Left(
        ApiFailure(
          message: 'nope',
          code: 'NOT_CHAT_MEMBER',
          detail: null,
          status: 403,
        ),
      ),
    );
    final container = await boot();

    final controller = container.read(chatPresenceProvider.notifier);
    controller.ensureFresh(chatId);
    await settle();
    controller.ensureFresh(chatId);
    await settle();

    expect(container.read(chatPeerOnlineProvider(chatId)), isNull);
    verify(
      () => getMembers.execute(
        chatId,
        limit: any(named: 'limit'),
        includePresence: true,
      ),
    ).called(1);
  });

  group('online count of a group', () {
    const groupId = 'g1';

    MembersPage roster({required List<bool> online, bool hasNext = false}) =>
        MembersPage(
          members: [for (var i = 0; i < online.length; i++) member(100 + i)],
          hasNext: hasNext,
          nextUserId: hasNext ? 100 + online.length : null,
          presence: [
            for (var i = 0; i < online.length; i++)
              MemberPresenceEntity(userId: 100 + i, isOnline: online[i]),
          ],
        );

    test('counts everyone the server says is here', () async {
      answerWith(roster(online: [true, false, true, true, false]));
      final container = await boot();

      container.read(chatOnlineCountProvider.notifier).ensureFresh(groupId);
      await settle();

      expect(container.read(chatMembersOnlineProvider(groupId)), 3);
    });

    test('asks for the largest page there is, with presence', () async {
      answerWith(roster(online: [true]));
      final container = await boot();

      container.read(chatOnlineCountProvider.notifier).ensureFresh(groupId);
      await settle();

      verify(
        () => getMembers.execute(
          groupId,
          limit: GetMembersUseCase.maxLimit,
          includePresence: true,
        ),
      ).called(1);
    });

    test('a group bigger than one page has no count, not a low one', () async {
      answerWith(roster(online: [true, true], hasNext: true));
      final container = await boot();

      container.read(chatOnlineCountProvider.notifier).ensureFresh(groupId);
      await settle();

      expect(container.read(chatMembersOnlineProvider(groupId)), isNull);
    });

    test(
      'is cached like the peer presence, and dropped the same way',
      () async {
        answerWith(roster(online: [true, true]));
        final container = await boot();

        final controller = container.read(chatOnlineCountProvider.notifier);
        controller.ensureFresh(groupId);
        await settle();
        controller.ensureFresh(groupId);
        await settle();

        verify(
          () => getMembers.execute(
            groupId,
            limit: any(named: 'limit'),
            includePresence: true,
          ),
        ).called(1);

        controller.invalidate();
        expect(container.read(chatMembersOnlineProvider(groupId)), isNull);
      },
    );

    test('does not touch the direct-chat cache', () async {
      answerWith(roster(online: [true, true]));
      final container = await boot();

      container.read(chatOnlineCountProvider.notifier).ensureFresh(groupId);
      await settle();

      expect(container.read(chatPeerOnlineProvider(groupId)), isNull);
    });
  });

  test('nobody signed in means nothing to ask about', () async {
    answerWith(page(peerOnline: true));
    final container = await boot(user: null);

    container.read(chatPresenceProvider.notifier).ensureFresh(chatId);
    await settle();

    verifyNever(
      () => getMembers.execute(
        any(),
        limit: any(named: 'limit'),
        includePresence: any(named: 'includePresence'),
      ),
    );
  });
}
