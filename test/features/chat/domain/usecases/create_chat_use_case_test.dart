import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late CreateChatUseCase useCase;
  late MockChatRepository mockRepository;

  setUpAll(() {
    // `any(named: 'chatType')` needs a dummy ChatType to hand around
    // (mocktail can't synthesise one for a non-nullable enum parameter).
    registerFallbackValue(ChatType.direct);
  });

  setUp(() {
    mockRepository = MockChatRepository();
    useCase = CreateChatUseCase(mockRepository);
  });

  const tChat = ChatEntity(
    id: 'a3f1c2d4-0000-4000-8000-000000000001',
    seqCounter: 0,
    lastActivityAt: null,
    type: ChatType.group,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: {},
    createdBy: 1,
    memberCount: 2,
  );

  void stubCreateChat() {
    when(
      () => mockRepository.createChat(
        name: any(named: 'name'),
        description: any(named: 'description'),
        chatType: any(named: 'chatType'),
        memberIds: any(named: 'memberIds'),
        isPublic: any(named: 'isPublic'),
        adminOnly: any(named: 'adminOnly'),
        slowModeSeconds: any(named: 'slowModeSeconds'),
        permissions: any(named: 'permissions'),
      ),
    ).thenAnswer((_) async => const Right(tChat));
  }

  void verifyNeverCalled() {
    verifyNever(
      () => mockRepository.createChat(
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

  // The endpoint allows only 4 creations per 5 minutes (api-docs §6.2), so
  // every rejected request below is a quarter of the user's budget saved.
  group('direct chat requires exactly one member id (api-docs §6.2)', () {
    test('accepts exactly one member id', () async {
      stubCreateChat();

      final result = await useCase.execute(
        chatType: ChatType.direct,
        memberIds: const [42],
      );

      expect(result.isRight(), isTrue);
      verify(
        () => mockRepository.createChat(
          name: null,
          description: null,
          chatType: ChatType.direct,
          memberIds: const [42],
          isPublic: false,
          adminOnly: false,
          slowModeSeconds: 0,
          permissions: null,
        ),
      ).called(1);
    });

    test('rejects an empty member list without calling the server', () async {
      final result = await useCase.execute(
        chatType: ChatType.direct,
        memberIds: const [],
      );

      final failure = result.getLeft().toNullable();
      expect(failure, isA<InputFailure>());
      // The server would answer `400 MEMBER_LIMIT_EXCEEDED` — a code that
      // points at the wrong problem for an *empty* list, so the local message
      // must explain the real mistake instead.
      expect(failure!.message.toLowerCase(), contains('exactly one'));
      verifyNeverCalled();
    });

    test('rejects two or more member ids', () async {
      final result = await useCase.execute(
        chatType: ChatType.direct,
        memberIds: const [1, 2],
      );

      final failure = result.getLeft().toNullable();
      expect(failure, isA<InputFailure>());
      expect(failure!.message, contains('group'));
      verifyNeverCalled();
    });

    test('defaults to direct, so a bare call is rejected too', () async {
      // `chat_type` defaults to "direct" server-side, which means an
      // argument-less create is a direct chat with zero participants.
      final result = await useCase.execute();

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNeverCalled();
    });
  });

  group('non-direct chats', () {
    test('requires a name', () async {
      final result = await useCase.execute(
        chatType: ChatType.group,
        memberIds: const [1, 2],
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNeverCalled();
    });

    test('rejects a whitespace-only name', () async {
      final result = await useCase.execute(
        name: '   ',
        chatType: ChatType.group,
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNeverCalled();
    });

    test('creates a group with a name and members', () async {
      stubCreateChat();

      final result = await useCase.execute(
        name: 'Team',
        chatType: ChatType.group,
        memberIds: const [1, 2, 3],
      );

      expect(result.getRight().toNullable(), tChat);
    });

    test('allows any number of members for a channel', () async {
      stubCreateChat();

      final result = await useCase.execute(
        name: 'Announcements',
        chatType: ChatType.channel,
        memberIds: const [1, 2, 3],
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('field limits (api-docs §6.2)', () {
    test('rejects a name longer than 255 characters', () async {
      final result = await useCase.execute(
        name: 'x' * (CreateChatUseCase.maxNameLength + 1),
        chatType: ChatType.group,
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNeverCalled();
    });

    test('rejects a description longer than 1024 characters', () async {
      final result = await useCase.execute(
        name: 'Team',
        description: 'x' * (CreateChatUseCase.maxDescriptionLength + 1),
        chatType: ChatType.group,
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNeverCalled();
    });

    test('rejects more than 100 initial members', () async {
      final result = await useCase.execute(
        name: 'Big',
        chatType: ChatType.supergroup,
        memberIds: List.generate(
          CreateChatUseCase.maxInitialMembers + 1,
          (i) => i + 1,
        ),
      );

      final failure = result.getLeft().toNullable();
      expect(failure, isA<InputFailure>());
      expect(failure!.message, contains('100'));
      verifyNeverCalled();
    });

    test('applies the per-type cap, not one global limit', () async {
      // `group` caps at 500 while `supergroup` allows a million (api-docs
      // §6.1). The initial-member cap (100) is the tighter of the two here,
      // so a 100-member list is the largest a `group` can be created with and
      // must be accepted rather than rejected by a mistakenly shared limit.
      stubCreateChat();

      final result = await useCase.execute(
        name: 'Crowd',
        chatType: ChatType.group,
        memberIds: List.generate(CreateChatUseCase.maxInitialMembers, (i) => i + 1),
      );

      expect(result.isRight(), isTrue);
      verify(
        () => mockRepository.createChat(
          name: 'Crowd',
          description: null,
          chatType: ChatType.group,
          memberIds: any(named: 'memberIds'),
          isPublic: false,
          adminOnly: false,
          slowModeSeconds: 0,
          permissions: null,
        ),
      ).called(1);
    });

    test('rejects a direct chat that would exceed its 2-member cap', () async {
      // The per-type cap is what makes `direct` different from every other
      // type: 2 members total, i.e. the caller plus exactly one other.
      expect(ChatType.direct.maxMembers, 2);
      expect(ChatType.group.maxMembers, 500);
      expect(ChatType.supergroup.maxMembers, 1000000);
      expect(ChatType.channel.maxMembers, 10000000);

      final result = await useCase.execute(
        chatType: ChatType.direct,
        memberIds: const [1, 2, 3],
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNeverCalled();
    });

    test('rejects duplicate member ids', () async {
      final result = await useCase.execute(
        name: 'Team',
        chatType: ChatType.group,
        memberIds: const [1, 1, 2],
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNeverCalled();
    });

    test('rejects slow mode above 86400 seconds', () async {
      final result = await useCase.execute(
        name: 'Team',
        chatType: ChatType.group,
        slowModeSeconds: CreateChatUseCase.maxSlowModeSeconds + 1,
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNeverCalled();
    });

    test('rejects negative slow mode', () async {
      final result = await useCase.execute(
        name: 'Team',
        chatType: ChatType.group,
        slowModeSeconds: -1,
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNeverCalled();
    });
  });

  test('propagates a repository failure unchanged', () async {
    when(
      () => mockRepository.createChat(
        name: any(named: 'name'),
        description: any(named: 'description'),
        chatType: any(named: 'chatType'),
        memberIds: any(named: 'memberIds'),
        isPublic: any(named: 'isPublic'),
        adminOnly: any(named: 'adminOnly'),
        slowModeSeconds: any(named: 'slowModeSeconds'),
        permissions: any(named: 'permissions'),
      ),
    ).thenAnswer(
      (_) async => const Left(
        // `409 DIRECT_CHAT_EXISTS` — the existing chat's id travels in
        // `detail.chat_id` so the UI can just open it (api-docs §6.2).
        ServerFailure(message: 'Direct chat already exists', statusCode: 409),
      ),
    );

    final result = await useCase.execute(
      chatType: ChatType.direct,
      memberIds: const [42],
    );

    expect(result.getLeft().toNullable()!.statusCode, 409);
  });
}
