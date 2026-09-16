import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/usecases/add_member_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/ban_member_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class _FakeAuth extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 1, username: 'me', email: 'me@example.com');
}

class _FakeGetChat implements GetChatUseCase {
  _FakeGetChat(this.chat);

  final ChatEntity chat;
  int calls = 0;

  @override
  Future<Either<Failure, ChatEntity>> execute(String chatId) async {
    calls++;
    return Right(chat);
  }
}

class _FakeGetMembers implements GetMembersUseCase {
  _FakeGetMembers(this.page);

  final MembersPage page;

  @override
  Future<Either<Failure, MembersPage>> execute(
    String chatId, {
    int limit = 50,
    int? cursorUserId,
    bool includePresence = false,
  }) async => Right(page);

  @override
  Future<Either<Failure, MembersPage>> executeNextPage(
    String chatId,
    MembersPage previous, {
    int limit = 50,
    bool includePresence = false,
  }) async =>
      const Right(MembersPage(members: [], hasNext: false, nextUserId: null));
}

/// Adds everyone but the user ids in [rejects], which answer the way the
/// server does when someone is already in the chat.
class _FakeAddMember implements AddMemberUseCase {
  _FakeAddMember({this.rejects = const {}});

  final Set<int> rejects;
  final List<(int, ChatRole)> calls = [];

  @override
  Future<Either<Failure, void>> execute(
    String chatId,
    int userId, {
    ChatRole role = ChatRole.member,
  }) async {
    calls.add((userId, role));
    if (rejects.contains(userId)) {
      return const Left(
        ApiFailure(
          message: 'already a member',
          code: 'ALREADY_CHAT_MEMBER',
          detail: null,
          status: 409,
        ),
      );
    }
    return const Right(null);
  }
}

class _FakeBanMember implements BanMemberUseCase {
  DateTime? lastBannedTo;
  bool liftCalled = false;

  @override
  Future<Either<Failure, void>> execute(
    String chatId,
    int userId, {
    String? reason,
    DateTime? bannedTo,
  }) async {
    lastBannedTo = bannedTo;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> lift(String chatId, int userId) async {
    liftCalled = true;
    return const Right(null);
  }
}

void main() {
  const chatId = 'c1';

  ChatMemberEntity member(int userId, ChatRole role, {bool isBanned = false}) =>
      ChatMemberEntity(
        userId: userId,
        roleId: role.id,
        isMuted: false,
        isBanned: isBanned,
        permissionsOverrides: const {},
      );

  final roster = [
    member(1, ChatRole.owner),
    member(5, ChatRole.member),
    member(9, ChatRole.member, isBanned: true),
  ];

  final chat = ChatEntity(
    id: chatId,
    seqCounter: 1,
    lastActivityAt: null,
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
    members: roster,
  );

  // What `GET /members/` answers: the banned member is simply not in it.
  final page = MembersPage(
    members: [member(1, ChatRole.owner), member(5, ChatRole.member)],
    hasNext: false,
    nextUserId: null,
    presence: const [MemberPresenceEntity(userId: 5, isOnline: true)],
  );

  Future<ProviderContainer> boot({
    AddMemberUseCase? addMember,
    BanMemberUseCase? banMember,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        getChatUseCaseProvider.overrideWithValue(_FakeGetChat(chat)),
        getMembersUseCaseProvider.overrideWithValue(_FakeGetMembers(page)),
        addMemberUseCaseProvider.overrideWithValue(
          addMember ?? _FakeAddMember(),
        ),
        banMemberUseCaseProvider.overrideWithValue(
          banMember ?? _FakeBanMember(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    // Without a listener the provider is disposed the moment the read
    // returns, and its first load never lands.
    container.listen(chatMembersProvider(chatId), (_, _) {});
    await container.read(chatMembersProvider(chatId).future);

    return container;
  }

  test('joins presence by user id; nobody named is offline', () async {
    final container = await boot();
    final state = container.read(chatMembersProvider(chatId)).requireValue;

    expect(state.isOnline(5), isTrue);
    expect(state.isOnline(1), isFalse);
  });

  test('banned members come off the chat detail, not the paged list', () async {
    final container = await boot();
    final state = container.read(chatMembersProvider(chatId)).requireValue;

    expect(state.members.map((m) => m.userId), [1, 5]);
    expect(state.banned.map((m) => m.userId), [9]);
    expect(state.knownMemberCount, 3);
  });

  test(
    'adding several people reports the ones that did not go through',
    () async {
      final add = _FakeAddMember(rejects: {7});
      final container = await boot(addMember: add);

      final outcome = await container
          .read(chatMembersProvider(chatId).notifier)
          .addMembers([6, 7, 8], role: ChatRole.viewer);

      expect(outcome.added, [6, 8]);
      expect(outcome.failed.keys, [7]);
      expect(outcome.isCompleteSuccess, isFalse);
      expect((outcome.firstFailure! as ApiFailure).code, 'ALREADY_CHAT_MEMBER');

      // The picked role travels with every request, not just the first.
      expect(add.calls.map((c) => c.$2).toSet(), {ChatRole.viewer});
    },
  );

  test('unbanning goes through lift(), which sends a past date', () async {
    final ban = _FakeBanMember();
    final container = await boot(banMember: ban);

    await container.read(chatMembersProvider(chatId).notifier).unbanMember(9);

    expect(ban.liftCalled, isTrue);
    expect(ban.lastBannedTo, isNull);
  });

  test('banning passes the expiry straight through', () async {
    final ban = _FakeBanMember();
    final container = await boot(banMember: ban);

    final until = DateTime.now().add(const Duration(days: 7));
    await container
        .read(chatMembersProvider(chatId).notifier)
        .banMember(5, reason: 'spam', bannedTo: until);

    expect(ban.lastBannedTo, until);
    expect(ban.liftCalled, isFalse);
  });
}
