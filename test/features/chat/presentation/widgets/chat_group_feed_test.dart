import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_context_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_header.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_message_row.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/chat_composer.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';
import '../../../../helpers/pane_frame.dart';

class _MockGetChatUseCase extends Mock implements GetChatUseCase {}

class _MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class _MockGetMessagesContextUseCase extends Mock
    implements GetMessagesContextUseCase {}

class _MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// A group conversation the way it is read: runs by several people, each
/// named over its first bubble and faced at its last, in a chat whose app bar
/// carries the group's own face.
void main() {
  const chatId = '3b0c9f6e-1d2a-4c5b-8e7f-6a5b4c3d2e1f';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  const ada = 42;
  const grace = 43;
  const linus = 44;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
    registerFallbackValue(
      const MessagesPage(messages: [], nextCursor: null, hasNext: false),
    );
  });

  const names = {
    ada: 'Ada Lovelace',
    grace: 'Grace Hopper',
    linus: 'Linus Torvalds',
    7: 'Me',
  };

  ChatProfileEntity profile(int userId) => ChatProfileEntity(
    userId: userId,
    username: names[userId]!.split(' ').first.toLowerCase(),
    displayName: names[userId],
    avatarUrl: null,
    avatarS3Key: null,
  );

  ChatMemberEntity member(int userId) => ChatMemberEntity(
    userId: userId,
    roleId: ChatRole.member.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
    profile: profile(userId),
  );

  /// Oldest first. Runs: Ada ×3, me ×2, Grace ×1 (a tall one), Linus ×2,
  /// Ada ×1 — minutes apart within a run, so the grouping holds.
  final script = <(int, String)>[
    (ada, 'Morning! Pushed the new message gutter'),
    (ada, 'Faces now sit at the foot of each run'),
    (ada, 'Same as in every other messenger'),
    (me.id, 'Nice, checking it now'),
    (me.id, 'Looks right on the phone'),
    (
      grace,
      'One thing worth checking is a long message: the face should hug '
          'the bottom of the bubble however many lines it wraps to, not '
          'float somewhere in the middle of it.',
    ),
    (linus, 'Desktop too?'),
    (linus, 'The pane there is narrower than the window'),
    (ada, 'Both. Every header measures its own pane now'),
  ];

  /// Newest first, the order `GET /messages/` returns.
  List<MessageEntity> conversation() {
    final messages = <MessageEntity>[];
    var minute = 0;
    int? lastAuthor;
    for (var i = 0; i < script.length; i++) {
      final (author, body) = script[i];
      // A new author starts a new run anyway; within one, a minute apart.
      minute += author == lastAuthor ? 1 : 2;
      lastAuthor = author;
      messages.add(
        MessageEntity(
          id: 'm${i + 1}',
          chatId: chatId,
          seq: i + 1,
          authorId: author,
          type: MessageType.text,
          content: body,
          replyToId: null,
          forwardedFromChatId: null,
          forwardedFromMessageId: null,
          forwardedFromAuthorId: null,
          isEdited: false,
          createdAt: DateTime(2026, 3, 2, 10).add(Duration(minutes: minute)),
          attachments: const [],
          profile: profile(author),
        ),
      );
    }
    return messages.reversed.toList();
  }

  ChatEntity chat() => ChatEntity(
    id: chatId,
    seqCounter: script.length,
    lastActivityAt: DateTime(2026, 3, 2, 10, 30),
    type: ChatType.group,
    name: 'Design Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: ada,
    memberCount: 4,
    unreadCount: 0,
    lastRead: ReadDetailEntity(
      lastReadMessageSeq: script.length,
      lastReadAt: DateTime(2026, 3, 2, 10, 30),
    ),
    members: [member(me.id), member(ada), member(grace), member(linus)],
  );

  late _MockGetChatUseCase getChat;
  late _MockGetMessagesUseCase getMessages;
  late _MockGetMessagesContextUseCase getContext;
  late _MockMarkReadUseCase markRead;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = _MockGetChatUseCase();
    getMessages = _MockGetMessagesUseCase();
    getContext = _MockGetMessagesContextUseCase();
    markRead = _MockMarkReadUseCase();
    channel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => channel,
    );

    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  /// The chat screen as the app builds it — app bar, feed, composer — in
  /// [window], beside a rail and a list where the window has them.
  Future<void> pumpScreen(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
  }) async {
    when(() => getChat.execute(chatId)).thenAnswer((_) async => Right(chat()));
    when(
      () => getMessages.execute(chatId, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Right(
        MessagesPage(
          messages: conversation(),
          nextCursor: null,
          hasNext: false,
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        getMessagesContextUseCaseProvider.overrideWithValue(getContext),
        markReadUseCaseProvider.overrideWithValue(markRead),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => _FakeAuthController(me)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.listen(chatDetailProvider(chatId), (_, _) {});
    await container.read(chatDetailProvider(chatId).future);

    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    // The mesh is seeded from the chat id; the pattern has its own goldens.
    final appearance = const AppearanceSettings().copyWith(
      wallpaperId: AppWallpaper.plain.id,
    );

    final screen = Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(chatDetailProvider(chatId)).value!;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: window.hasList ? null : const BackButton(),
            titleSpacing: 0,
            title: ChatHeaderTitle(
              chatId: chatId,
              chat: state.chat,
              myUserId: me.id,
              onTap: () {},
            ),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.call_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ChatFeed(
                  chatId: chatId,
                  state: state,
                  myUserId: me.id,
                  selectionMode: false,
                  selectedIds: const {},
                  onStartSelection: (_) {},
                  onToggleSelected: (_) {},
                  onEdit: (_) {},
                  onRefresh: () async {},
                ),
              ),
              ChatComposer(
                controller: controller,
                focusNode: focusNode,
                length: 0,
                hasAttachments: false,
                isRecording: false,
                isSending: false,
                slowMode: SlowMode.off,
                replyTo: null,
                editing: null,
                onAttach: () {},
                onSend: () {},
                onVoiceRecorded: (_) {},
              ),
            ],
          ),
        );
      },
    );

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark(appearance) : AppTheme.light(appearance),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(window: window, child: screen),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Lets the sticky date chip fade, so a golden shows the feed at rest.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Finder feedAvatars() => find.descendant(
    of: find.byType(ChatFeed),
    matching: find.byType(ChatAvatar),
  );

  Finder rowOf(String messageId) => find.byWidgetPredicate(
    (widget) => widget is ChatMessageRow && widget.item.message.id == messageId,
  );

  /// The bubble's painted ground in the row for [messageId].
  Finder groundOf(String messageId) => find.descendant(
    of: rowOf(messageId),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox && widget.decoration is ShapeDecoration,
    ),
  );

  Finder avatarIn(String messageId) =>
      find.descendant(of: rowOf(messageId), matching: find.byType(ChatAvatar));

  Rect faceRect(WidgetTester tester, Finder avatar) => tester.getRect(
    find.descendant(of: avatar, matching: find.byType(ClipPath)).first,
  );

  /// The last message of each incoming run, in the script's numbering.
  const runTails = ['m3', 'm6', 'm8', 'm9'];

  /// …and the first, where the name goes.
  const runHeads = {'m1': ada, 'm6': grace, 'm7': linus, 'm9': ada};

  group('the face beside a run', () {
    testWidgets('goes on the last bubble of each run, and only there', (
      tester,
    ) async {
      await pumpScreen(tester);

      for (final id in runTails) {
        expect(avatarIn(id), findsOneWidget, reason: id);
      }
      for (final id in ['m1', 'm2', 'm7']) {
        expect(avatarIn(id), findsNothing, reason: id);
      }
      expect(feedAvatars(), findsNWidgets(runTails.length));
    });

    testWidgets('is a 32 px circle level with the bottom of that bubble', (
      tester,
    ) async {
      await pumpScreen(tester);

      for (final id in runTails) {
        final face = faceRect(tester, avatarIn(id));
        final bubble = tester.getRect(groundOf(id));

        expect(face.size, Size.square(ChatAvatarSize.sm.diameter), reason: id);
        expect(face.bottom, moreOrLessEquals(bubble.bottom), reason: id);
      }
    });

    testWidgets('sits in a gutter made of inset, face and gap', (tester) async {
      await pumpScreen(tester);

      final feedLeft = tester.getTopLeft(find.byType(ChatFeed)).dx;
      final gutter = ChatLayout.avatarGutterFor(ChatAvatarSize.sm.diameter);

      for (final id in runTails) {
        final face = faceRect(tester, avatarIn(id));
        expect(face.left - feedLeft, ChatLayout.avatarInset, reason: id);
      }

      // Every incoming bubble starts at the gutter, faced or not, so a run
      // stays one column.
      for (final id in ['m1', 'm2', 'm3', 'm6', 'm7', 'm8', 'm9']) {
        final bubble = tester.getRect(groundOf(id));
        expect(bubble.left - feedLeft, gutter, reason: id);
      }
    });

    testWidgets('is the colour of the name above the run', (tester) async {
      await pumpScreen(tester);

      final ground = tester
          .widgetList<Container>(
            find.descendant(
              of: avatarIn('m3'),
              matching: find.byType(Container),
            ),
          )
          .map((container) => container.color)
          .whereType<Color>()
          .first;
      final name = tester.widget<Text>(find.text(names[ada]!).first);

      expect(name.style?.color, ground);
    });
  });

  group('the name over a run', () {
    testWidgets('heads the first bubble, above the face at the foot', (
      tester,
    ) async {
      await pumpScreen(tester);

      for (final MapEntry(key: id, value: author) in runHeads.entries) {
        final name = find.descendant(
          of: rowOf(id),
          matching: find.text(names[author]!),
        );
        expect(name, findsOneWidget, reason: id);
      }

      // Ada's first run: named on m1, faced on m3.
      final name = tester.getRect(
        find.descendant(of: rowOf('m1'), matching: find.text(names[ada]!)),
      );
      final face = faceRect(tester, avatarIn('m3'));
      expect(name.bottom, lessThan(face.top));
    });

    testWidgets('is not repeated inside a run', (tester) async {
      await pumpScreen(tester);

      for (final id in ['m2', 'm3', 'm8']) {
        expect(
          find.descendant(
            of: rowOf(id),
            matching: find.textContaining(RegExp('Ada|Linus')),
          ),
          findsNothing,
          reason: id,
        );
      }
    });
  });

  testWidgets('the app bar carries the group, drawn at header size', (
    tester,
  ) async {
    await pumpScreen(tester);

    final mosaic = find.descendant(
      of: find.byType(ChatHeaderTitle),
      matching: find.byType(ChatAvatarMosaic),
    );
    expect(mosaic, findsOneWidget);
    expect(
      tester.getSize(
        find.descendant(of: mosaic, matching: find.byType(ClipOval)),
      ),
      Size.square(ChatAvatarSize.md.diameter),
    );
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('a group feed, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pumpScreen(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'group_feed_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
