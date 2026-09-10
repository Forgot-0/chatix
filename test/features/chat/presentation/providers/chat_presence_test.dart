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
