import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_context_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_date_separator.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_jump_button.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_wallpaper.dart';
import 'package:chatix/features/chat/presentation/widgets/date_chip.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/unread_divider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

class MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class MockGetMessagesContextUseCase extends Mock
    implements GetMessagesContextUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// The feed as the reader meets it: where it opens, what it reports having
/// shown, and what it does to a thousand messages.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');
  const viewport = Size(400, 600);

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
    registerFallbackValue(
      const MessagesPage(messages: [], nextCursor: null, hasNext: false),
    );
  });

  MessageEntity message(int seq) => MessageEntity(
    id: 'm$seq',
    chatId: chatId,
    seq: seq,
    authorId: 42,
    type: MessageType.text,
    content: 'message $seq',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    // Spread across days so the sticky header has something to name.
    createdAt: DateTime.utc(2026, 1, 1).add(Duration(hours: seq)),
    attachments: const [],
  );

  /// Newest first, the order `GET /messages/` returns.
  List<MessageEntity> window(int newest, int count) => [
    for (var seq = newest; seq > newest - count; seq--) message(seq),
  ];

  ChatEntity chatWith({int? lastReadSeq, int unread = 0}) => ChatEntity(
    id: chatId,
    seqCounter: 400,
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
    unreadCount: unread,
    lastRead: lastReadSeq == null
        ? null
        : ReadDetailEntity(
            lastReadMessageSeq: lastReadSeq,
            lastReadAt: DateTime.utc(2026, 1, 1),
          ),
  );

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockGetMessagesContextUseCase getContext;
  late MockMarkReadUseCase markRead;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    getContext = MockGetMessagesContextUseCase();
    markRead = MockMarkReadUseCase();
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

  Future<ProviderContainer> pumpFeed(
    WidgetTester tester, {
    required ChatEntity chat,
    required List<MessageEntity> messages,
    bool hasNext = false,
    bool dark = false,
    bool reduceMotion = false,
    AppWallpaper wallpaper = AppWallpaper.aurora,
  }) async {
    when(() => getChat.execute(chatId)).thenAnswer((_) async => Right(chat));
    when(
      () => getMessages.execute(chatId, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Right(
        MessagesPage(
          messages: messages,
          nextCursor: hasNext ? messages.last.seq : null,
          hasNext: hasNext,
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
        authProvider.overrideWith(() => FakeAuthController(me)),
        wallpaperProvider.overrideWithValue(wallpaper),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.listen(chatDetailProvider(chatId), (_, _) {});
    await container.read(chatDetailProvider(chatId).future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: viewport.width,
                height: viewport.height,
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: reduceMotion),
                    child: Consumer(
                      builder: (context, ref, _) => ChatFeed(
                        chatId: chatId,
                        state: ref.watch(chatDetailProvider(chatId)).value!,
                        myUserId: me.id,
                        selectionMode: false,
                        selectedIds: const {},
                        onStartSelection: (_) {},
                        onToggleSelected: (_) {},
                        onEdit: (_) {},
                        onRefresh: () async {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return container;
  }

  ScrollableState scrollable(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first);

  group('opening position', () {
    testWidgets('a chat with no unread opens on the newest message', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 60),
      );

      expect(find.text('message 100'), findsOneWidget);
      expect(scrollable(tester).position.pixels, 0);
    });

    testWidgets('unread messages put the divider on screen instead', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 70, unread: 30),
        messages: window(100, 60),
      );

      // The divider is roughly thirty messages up: landing on it means the
      // list did not simply stay at the bottom.
      expect(find.byType(UnreadDivider), findsOneWidget);
      expect(scrollable(tester).position.pixels, greaterThan(0));
      expect(find.text('message 100'), findsNothing);
    });

    testWidgets('a boundary above the loaded window is fetched first', (
      tester,
    ) async {
      // Read stopped at seq 40 while the freshest page starts at 71.
      when(
        () => getContext.execute(chatId, 40, limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => Right(
          MessagesPage(messages: window(60, 40), nextCursor: 20, hasNext: true),
        ),
      );

      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 40, unread: 60),
        messages: window(100, 30),
        hasNext: true,
      );

      verify(
        () => getContext.execute(chatId, 40, limit: any(named: 'limit')),
      ).called(1);
      expect(find.byType(UnreadDivider), findsOneWidget);
    });
  });

  group('read reporting', () {
    testWidgets('reports the newest message actually on screen', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 60),
      );

      verify(() => markRead.execute(chatId, 100)).called(1);
    });

    testWidgets('opening at the divider does not report the newest', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 70, unread: 30),
        messages: window(100, 60),
      );

      // Reading resumed at the divider, which is what the server should hear
      // about — marking seq 100 read would wipe a badge for thirty messages
      // still below the fold.
      verifyNever(() => markRead.execute(chatId, 100));
      final captured = verify(
        () => markRead.execute(chatId, captureAny()),
      ).captured.cast<int>();
      expect(captured, isNotEmpty);
      expect(captured.reduce((a, b) => a > b ? a : b), lessThan(100));
    });
  });

  group('jump to bottom', () {
    double opacityOf(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(ChatJumpToBottomButton),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('stays hidden while the reader is near the bottom', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 60),
      );

      scrollable(tester).position.jumpTo(viewport.height);
      await tester.pumpAndSettle();

      expect(opacityOf(tester), 0);
    });

    testWidgets('appears past one and a half screens of history', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 60),
      );

      scrollable(tester).position.jumpTo(viewport.height * 1.6);
      await tester.pumpAndSettle();

      expect(opacityOf(tester), 1);
    });

    testWidgets('tapping it returns to the newest message', (tester) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 60),
      );

      scrollable(tester).position.jumpTo(viewport.height * 2);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(scrollable(tester).position.pixels, 0);
      expect(find.text('message 100'), findsOneWidget);
    });
  });

  group('sticky date', () {
    DateChip stickyChip(WidgetTester tester) => tester.widget<DateChip>(
      find.descendant(
        of: find.byType(ChatStickyDate),
        matching: find.byType(DateChip),
      ),
    );

    testWidgets('rides the top while moving and fades once settled', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 60),
      );

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pump();

      expect(stickyChip(tester).visible, isTrue);
      expect(stickyChip(tester).elevated, isTrue);

      // Long enough for the list to count as settled, plus the fade out.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(stickyChip(tester).visible, isFalse);
      expect(stickyChip(tester).elevated, isFalse);
    });
  });

  group('paging up', () {
    testWidgets('a page arriving above the reader does not move them', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 30),
        hasNext: true,
      );

      when(
        () =>
            getMessages.executeOlder(chatId, any(), limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => Right(
          MessagesPage(
            messages: window(70, 30),
            nextCursor: null,
            hasNext: false,
          ),
        ),
      );

      // Close to the far end, but short of the slack that triggers paging.
      // Frames are pumped by hand from here: the load-more spinner never
      // stops animating, so there is nothing for pumpAndSettle to settle on.
      final position = scrollable(tester).position;
      position.jumpTo(position.maxScrollExtent - 400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final extentBefore = position.maxScrollExtent;

      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      final before = scrollable(tester).position.pixels;
      final anchored = find.text('message 71');
      expect(anchored, findsOneWidget);
      final anchorTop = tester.getTopLeft(anchored).dy;

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Thirty older messages landed beyond the far end of a reverse list, so
      // they extend the scrollable without touching the offset the reader is
      // parked at.
      expect(scrollable(tester).position.pixels, before);
      expect(
        scrollable(tester).position.maxScrollExtent,
        greaterThan(extentBefore),
      );
      expect(tester.getTopLeft(anchored).dy, anchorTop);

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('jumping to a message', () {
    testWidgets('lights the target and lets the light fade', (tester) async {
      final container = await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 60),
      );

      await container
          .read(chatDetailProvider(chatId).notifier)
          .revealMessage('m50');
      await tester.pumpAndSettle();

      expect(find.text('message 50'), findsOneWidget);
      expect(
        tester
            .widgetList<MessageBubble>(find.byType(MessageBubble))
            .where((bubble) => bubble.isHighlighted)
            .length,
        1,
      );

      // The flash is a flash: it clears itself rather than leaving the chat
      // permanently marked up.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<MessageBubble>(find.byType(MessageBubble))
            .where((bubble) => bubble.isHighlighted),
        isEmpty,
      );
      expect(
        container.read(chatDetailProvider(chatId)).value!.highlightMessageId,
        isNull,
      );
    });
  });

  group('the app going away', () {
    testWidgets('nothing is reported read while the app is not in front', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 70, unread: 30),
        messages: window(100, 60),
      );
      clearInteractions(markRead);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      scrollable(tester).position.jumpTo(0);
      await tester.pumpAndSettle();

      // The newest message is on screen, but nobody is looking at it.
      verifyNever(() => markRead.execute(any(), any()));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Coming back queues the report behind whatever is left of the throttle
      // window the opening scroll opened.
      await tester.pump(
        ChatDetailController.readThrottle + const Duration(milliseconds: 100),
      );

      verify(() => markRead.execute(chatId, 100)).called(1);
    });
  });

  group('wallpaper parallax', () {
    double? meshOffset(WidgetTester tester) {
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(ChatWallpaper),
          matching: find.byType(Transform),
        ),
      );
      if (transforms.isEmpty) return null;
      return transforms.first.transform.getTranslation().y;
    }

    testWidgets('the pattern drifts against the messages', (tester) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 60),
      );

      expect(meshOffset(tester), 0);

      scrollable(tester).position.jumpTo(700);
      await tester.pumpAndSettle();

      final drifted = meshOffset(tester)!;
      expect(drifted, isNot(0));
      // Small on purpose: it should read as depth, not as a moving floor.
      expect(drifted.abs(), lessThanOrEqualTo(ChatWallpaper.maxParallax));
    });

    testWidgets('reduced motion holds the pattern still', (tester) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 100),
        messages: window(100, 60),
        reduceMotion: true,
      );

      scrollable(tester).position.jumpTo(700);
      await tester.pumpAndSettle();

      expect(meshOffset(tester), isNull);
    });
  });

  group('a thousand messages', () {
    testWidgets('only builds the rows the viewport needs', (tester) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 1200),
        messages: window(1200, 1200),
      );

      // A 600px viewport plus the cache extent is a couple of dozen rows.
      // Anything near the full window means the list stopped being lazy.
      final built = tester
          .widgetList<MessageBubble>(
            find.byType(MessageBubble, skipOffstage: false),
          )
          .length;

      expect(built, lessThan(60));
      expect(built, greaterThan(0));
    });

    testWidgets('scrolling deep into it keeps the same handful of rows', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        chat: chatWith(lastReadSeq: 1200),
        messages: window(1200, 1200),
      );

      scrollable(tester).position.jumpTo(12000);
      await tester.pumpAndSettle();

      final built = tester
          .widgetList<MessageBubble>(
            find.byType(MessageBubble, skipOffstage: false),
          )
          .length;

      expect(built, lessThan(60));
    });
  });

  group('goldens', () {
    ChatProfileEntity profile(int userId, String name) => ChatProfileEntity(
      userId: userId,
      username: name.toLowerCase(),
      displayName: name,
      avatarUrl: null,
      avatarS3Key: null,
    );

    /// A conversation with runs in it: two authors, minutes apart, with the
    /// read cursor sitting in the middle.
    List<MessageEntity> conversation() {
      final authors = {
        1: (42, 'Ada'),
        2: (42, 'Ada'),
        3: (42, 'Ada'),
        4: (7, 'Me'),
        5: (7, 'Me'),
        6: (43, 'Grace'),
        7: (43, 'Grace'),
        8: (42, 'Ada'),
      };
      final bodies = {
        1: 'Pushed the branch, take a look when you can',
        2: 'The failing case was the empty window',
        3: 'Fixed now',
        4: 'Nice, reviewing it',
        5: 'One comment on the cursor handling',
        6: 'I hit the same thing last week',
        7: 'Glad it was not just me',
        8: 'Shipping it after lunch then',
      };

      return [
        for (var seq = 8; seq >= 1; seq--)
          MessageEntity(
            id: 'm$seq',
            chatId: chatId,
            seq: seq,
            authorId: authors[seq]!.$1,
            type: MessageType.text,
            content: bodies[seq],
            replyToId: null,
            forwardedFromChatId: null,
            forwardedFromMessageId: null,
            forwardedFromAuthorId: null,
            isEdited: false,
            createdAt: DateTime(2026, 1, 1, 9).add(Duration(minutes: seq)),
            attachments: const [],
            profile: profile(authors[seq]!.$1, authors[seq]!.$2),
          ),
      ];
    }

    for (final entry in {'light': false, 'dark': true}.entries) {
      testGoldens('the feed on the ${entry.key} theme', (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpFeed(
          tester,
          chat: chatWith(lastReadSeq: 5, unread: 3),
          messages: conversation(),
          dark: entry.value,
          // The mesh is seeded from the chat id, and a hash that shifts
          // between SDKs would make this golden a liability. The pattern has
          // its own tests.
          wallpaper: AppWallpaper.plain,
        );

        await screenMatchesGolden(tester, 'chat_feed_${entry.key}');
      });
    }
  });

  group('both themes', () {
    for (final dark in [false, true]) {
      testWidgets('renders without overflow in ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await pumpFeed(
          tester,
          chat: chatWith(lastReadSeq: 70, unread: 30),
          messages: window(100, 60),
          dark: dark,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(UnreadDivider), findsOneWidget);
      });
    }
  });
}
