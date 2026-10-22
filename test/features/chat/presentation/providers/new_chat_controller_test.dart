import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/upload_chat_avatar_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/new_chat_provider.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';

class _MockCreateChat extends Mock implements CreateChatUseCase {}

class _MockUploadAvatar extends Mock implements UploadChatAvatarUseCase {}

class _FakeChatList extends ChatListController {
  final List<ChatEntity> adopted = [];

  @override
  Future<ChatListState> build() async => const ChatListState();

  @override
  void adoptRow(ChatEntity chat) => adopted.add(chat);
}

ChatEntity created(String id, ChatType type) => ChatEntity(
  id: id,
  seqCounter: 0,
  lastActivityAt: DateTime.utc(2026, 10, 22),
  type: type,
  name: 'Release',
  description: null,
  avatarS3Key: null,
  isPublic: false,
  adminOnly: false,
  slowModeSeconds: 0,
  permissions: const {},
  createdBy: 7,
  memberCount: 1,
);

/// Creating a group or channel from the flow's draft: what is sent, what
/// happens when some people cannot be added, and the picture after.
void main() {
  late _MockCreateChat createChat;
  late _MockUploadAvatar uploadAvatar;
  late _FakeChatList chatList;
  late ProviderContainer container;
  late List<Invocation> calls;

  final ann = const NewChatMember(userId: 9, name: 'Ann');
  final bob = const NewChatMember(userId: 10, name: 'Bob');
  final cid = const NewChatMember(userId: 11, name: 'Cid');

  setUpAll(() {
    registerFallbackValue(ChatType.group);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() async {
    createChat = _MockCreateChat();
    uploadAvatar = _MockUploadAvatar();
    chatList = _FakeChatList();
    calls = [];
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        createChatUseCaseProvider.overrideWithValue(createChat),
        uploadChatAvatarUseCaseProvider.overrideWithValue(uploadAvatar),
        chatListProvider.overrideWith(() => chatList),
      ],
    );
    addTearDown(container.dispose);
    await container.read(chatListProvider.future);
  });

  void answerCreate(
    Either<Failure, ChatEntity> Function(Invocation call) answer,
  ) {
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
    ).thenAnswer((call) async {
      calls.add(call);
      return answer(call);
    });
  }

  /// Every `POST /chats/` the flow made, oldest first, by argument name.
  List<Map<Symbol, Object?>> createCalls() => [
    for (final call in calls) call.namedArguments,
  ];

  /// Keeps the autoDispose flow alive for the length of a test, as the
  /// screens watching it do.
  NewChatController flow(NewChatKind kind) {
    final provider = newChatProviderOf(kind);
    container.listen(provider, (_, _) {}, fireImmediately: true);
    return container.read(provider.notifier);
  }

  test('a draft without a name is refused before any request', () async {
    final group = flow(NewChatKind.group)..toggle(ann);

    final result = await group.submit();

    expect(
      result.getLeft().toNullable(),
      const NewChatValidationFailure(NewChatProblem.nameMissing),
    );
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
  });

  test('a group goes out as a private "group" with its people', () async {
    answerCreate((_) => Right(created('g1', ChatType.group)));
    final group = flow(NewChatKind.group)
      ..toggle(ann)
      ..toggle(bob)
      ..setName('  Release  ')
      ..setDescription('   ');

    final result = await group.submit();

    expect(result.getRight().toNullable()?.chatId, 'g1');
    final call = createCalls().single;
    expect(call[#name], 'Release');
    expect(call[#description], isNull, reason: 'blank is not a description');
    expect(call[#chatType], ChatType.group);
    expect(call[#memberIds], [9, 10]);
    expect(call[#isPublic], isFalse);
    // The row is in the list at once, with no refetch of the whole list.
    expect(chatList.adopted.single.id, 'g1');
  });

  test('a public channel says so; its subscribers ride along', () async {
    answerCreate((_) => Right(created('ch1', ChatType.channel)));
    final channel = flow(NewChatKind.channel)
      ..setName('News')
      ..setDescription('Daily')
      ..setPublic(true)
      ..toggle(cid);

    await channel.submit();

    final call = createCalls().single;
    expect(call[#chatType], ChatType.channel);
    expect(call[#isPublic], isTrue);
    expect(call[#description], 'Daily');
    expect(call[#memberIds], [11]);
  });

  test('people whose privacy keeps them out are left out, and named', () async {
    var attempt = 0;
    answerCreate((call) {
      attempt++;
      if (attempt == 1) {
        return const Left(
          ApiFailure(
            code: 'USER_PRIVACY_RESTRICTED',
            message: 'restricted',
            detail: {
              'user_ids': [10, 11],
            },
            status: 403,
          ),
        );
      }
      return Right(created('g2', ChatType.group));
    });
    final group = flow(NewChatKind.group)
      ..toggle(ann)
      ..toggle(bob)
      ..toggle(cid)
      ..setName('Release');

    final result = await group.submit();

    final outcome = result.getRight().toNullable()!;
    expect(outcome.chatId, 'g2');
    expect(outcome.notAdded, [bob, cid]);
    final calls = createCalls();
    expect(calls, hasLength(2));
    expect(calls[0][#memberIds], [9, 10, 11]);
    expect(calls[1][#memberIds], [9]);
  });

  test(
    'any other refusal is handed back, and the form comes back to life',
    () async {
      answerCreate(
        (_) => const Left(
          ApiFailure(
            code: 'MEMBER_LIMIT_EXCEEDED',
            message: 'limit',
            detail: {'limit': 500},
            status: 400,
          ),
        ),
      );
      final group = flow(NewChatKind.group)..setName('Release');

      final result = await group.submit();

      expect(result.getLeft().toNullable(), isA<ApiFailure>());
      expect(container.read(newGroupProvider).isSubmitting, isFalse);
      expect(createCalls(), hasLength(1));
    },
  );

  test('the picture goes up once the chat exists', () async {
    answerCreate((_) => Right(created('g3', ChatType.group)));
    when(
      () => uploadAvatar.execute(
        any(),
        bytes: any(named: 'bytes'),
        mimeType: any(named: 'mimeType'),
      ),
    ).thenAnswer((_) async => const Right(null));
    final photo = NewChatPhoto(
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/png',
    );
    final group = flow(NewChatKind.group)
      ..setName('Release')
      ..setPhoto(photo);

    final result = await group.submit();

    expect(result.getRight().toNullable()?.photoFailed, isFalse);
    verify(
      () =>
          uploadAvatar.execute('g3', bytes: photo.bytes, mimeType: 'image/png'),
    ).called(1);
  });

  test('a picture that does not go up does not undo the chat', () async {
    answerCreate((_) => Right(created('g4', ChatType.group)));
    when(
      () => uploadAvatar.execute(
        any(),
        bytes: any(named: 'bytes'),
        mimeType: any(named: 'mimeType'),
      ),
    ).thenAnswer((_) async => const Left(NetworkFailure()));
    final group = flow(NewChatKind.group)
      ..setName('Release')
      ..setPhoto(
        NewChatPhoto(bytes: Uint8List.fromList([1]), mimeType: 'image/png'),
      );

    final result = await group.submit();

    final outcome = result.getRight().toNullable()!;
    expect(outcome.chatId, 'g4');
    expect(outcome.photoFailed, isTrue);
  });

  test('no picture, no upload', () async {
    answerCreate((_) => Right(created('g5', ChatType.group)));
    final group = flow(NewChatKind.group)..setName('Release');

    await group.submit();

    verifyNever(
      () => uploadAvatar.execute(
        any(),
        bytes: any(named: 'bytes'),
        mimeType: any(named: 'mimeType'),
      ),
    );
  });

  test('a second press while the first is on the wire sends nothing', () async {
    answerCreate((_) => Right(created('g6', ChatType.group)));
    final group = flow(NewChatKind.group)..setName('Release');

    final first = group.submit();
    final second = await group.submit();
    await first;

    expect(second.getLeft().toNullable(), isA<CancelledFailure>());
    expect(createCalls(), hasLength(1));
  });

  test('the two flows keep their own drafts', () {
    flow(NewChatKind.group).setName('Group');
    flow(NewChatKind.channel).setName('Channel');

    expect(container.read(newGroupProvider).draft.name, 'Group');
    expect(container.read(newChannelProvider).draft.name, 'Channel');
    expect(container.read(newChannelProvider).draft.kind, NewChatKind.channel);
  });
}
