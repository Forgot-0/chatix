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
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/remove_reaction_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/reaction_notice_provider.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

class MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class MockSetReactionUseCase extends Mock implements SetReactionUseCase {}

class MockRemoveReactionUseCase extends Mock implements RemoveReactionUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// A reaction has to land before the request does — the chip is the feedback
/// for the tap. What the server says afterwards either confirms it silently
/// or takes it back with a word (api-docs §5.7.6).
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const messageId = 'm1';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  MessageEntity message({List<ReactionGroupEntity> reactions = const []}) =>
      MessageEntity(
        id: messageId,
        chatId: chatId,
        seq: 1,
        authorId: 42,
        type: MessageType.text,
        content: 'hello',
        replyToId: null,
        forwardedFromChatId: null,
        forwardedFromMessageId: null,
        forwardedFromAuthorId: null,
        isEdited: false,
        createdAt: DateTime.utc(2026, 1, 1),
        attachments: const [],
        reactions: reactions,
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
  late MockSetReactionUseCase setReaction;
  late MockRemoveReactionUseCase removeReaction;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    markRead = MockMarkReadUseCase();
    setReaction = MockSetReactionUseCase();
    removeReaction = MockRemoveReactionUseCase();
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
        MessagesPage(messages: [message()], nextCursor: null, hasNext: false),
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

  void answerSet(Either<Failure, void> result) {
    when(
      () => setReaction.execute(
        chatId,
        messageId,
        any(),
        current: any(named: 'current'),
        policy: any(named: 'policy'),
      ),
    ).thenAnswer((_) async => result);
  }

  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        markReadUseCaseProvider.overrideWithValue(markRead),
        setReactionUseCaseProvider.overrideWithValue(setReaction),
        removeReactionUseCaseProvider.overrideWithValue(removeReaction),
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

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  MessageReactionsEntity reactionsOf(ProviderContainer container) =>
      container.read(chatDetailProvider(chatId)).value!.reactionsFor(messageId);

  Map<String, dynamic> reactionUpdate(
    List<Map<String, dynamic>> groups, {
    int actorId = 42,
    String action = 'add',
    String eventId = 'e-1',
  }) => {
    'type': 'reaction_update',
    'chat_id': chatId,
    'payload': {
      'event_id': eventId,
      'event_name': 'chats.message.reaction_updated',
      'event': {'message_id': messageId, 'actor_id': actorId, 'action': action},
      'message': null,
      'reaction': {
        'message_id': messageId,
        'chat_id': chatId,
        'actor_id': actorId,
        'action': action,
        'groups': groups,
      },
    },
    'ts': '2026-01-15T10:30:00Z',
  };

  group('the chip appears before the request answers', () {
    test('and stays when the server accepts it', () async {
      answerSet(const Right(null));
      final container = await boot();

      final pending = container
          .read(chatDetailProvider(chatId).notifier)
          .toggleReaction(messageId, '👍');

      // Before the future completes, the chip is already there.
      expect(reactionsOf(container).isMine('👍'), isTrue);

      await pending;
      expect(reactionsOf(container).isMine('👍'), isTrue);
      expect(container.read(reactionNoticeProvider), isNull);
    });

    test('and comes back off when the server refuses', () async {
      answerSet(
        const Left(
          ApiFailure(
            code: 'REACTION_NOT_ALLOWED',
            message: 'no',
            detail: null,
            status: 400,
          ),
        ),
      );
      final container = await boot();

      await container
          .read(chatDetailProvider(chatId).notifier)
          .toggleReaction(messageId, '👍');

      expect(reactionsOf(container).groups, isEmpty);
    });

    test('a rollback says why, quietly', () async {
      answerSet(const Left(RateLimitFailure()));
      final container = await boot();

      await container
          .read(chatDetailProvider(chatId).notifier)
          .toggleReaction(messageId, '👍');

      expect(
        container.read(reactionNoticeProvider)?.reason,
        ReactionNoticeReason.tooFast,
      );
    });

    test('a cancelled request is not worth a word', () async {
      // The screen closed mid-flight; nobody failed at anything.
      answerSet(const Left(CancelledFailure()));
      final container = await boot();

      await container
          .read(chatDetailProvider(chatId).notifier)
          .toggleReaction(messageId, '👍');

      expect(container.read(reactionNoticeProvider), isNull);
      expect(reactionsOf(container).groups, isEmpty);
    });
  });

  group('reaction_update carries a whole snapshot, not a delta (§5.7.6)', () {
    test('the groups are replaced wholesale', () async {
      final container = await boot();

      channel.emit(
        reactionUpdate([
          {
            'emoji': '🔥',
            'count': 4,
            'version': 1,
            'reacted_by_me': false,
            'recent_user_ids': [42],
          },
        ]),
      );
      await settle();

      expect(reactionsOf(container).groups.map((g) => g.emoji), ['🔥']);
      expect(reactionsOf(container).groups.single.count, 4);
    });

    test('a coalesced burst lands as one final snapshot', () async {
      // The server consolidates a spike into ≤ 1 message per 500 ms and the
      // snapshot is always the final one, so the last frame wins outright.
      final container = await boot();

      channel.emit(
        reactionUpdate(eventId: 'e-first', [
          {
            'emoji': '🔥',
            'count': 2,
            'version': 1,
            'reacted_by_me': false,
            'recent_user_ids': <int>[],
          },
        ]),
      );
      await settle();

      channel.emit(
        reactionUpdate(eventId: 'e-final', [
          {
            'emoji': '🔥',
            'count': 17,
            'version': 2,
            'reacted_by_me': false,
            'recent_user_ids': <int>[],
          },
          {
            'emoji': '👍',
            'count': 3,
            'version': 2,
            'reacted_by_me': false,
            'recent_user_ids': <int>[],
          },
        ]),
      );
      await settle();

      expect(reactionsOf(container).groups.map((g) => g.count), [17, 3]);
    });

    test('a redelivered frame changes nothing (at-least-once)', () async {
      final container = await boot();

      Map<String, dynamic> frame() => reactionUpdate([
        {
          'emoji': '🔥',
          'count': 5,
          'version': 1,
          'reacted_by_me': false,
          'recent_user_ids': <int>[],
        },
      ]);

      channel.emit(frame());
      await settle();
      channel.emit(frame());
      await settle();

      expect(reactionsOf(container).groups.single.count, 5);
    });

    test(
      'reacted_by_me is always false on the wire, and ours survives it',
      () async {
        answerSet(const Right(null));
        final container = await boot();

        await container
            .read(chatDetailProvider(chatId).notifier)
            .toggleReaction(messageId, '👍');

        // Somebody else joins the same emoji. The event cannot tell us that we
        // are in it, so the local flag is what keeps the chip highlighted.
        channel.emit(
          reactionUpdate([
            {
              'emoji': '👍',
              'count': 2,
              'version': 1,
              'reacted_by_me': false,
              'recent_user_ids': [42],
            },
          ]),
        );
        await settle();

        final group = reactionsOf(container).groups.single;
        expect(group.count, 2);
        expect(group.reactedByMe, isTrue);
      },
    );
  });
}
