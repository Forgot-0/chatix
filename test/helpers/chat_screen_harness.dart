import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/notifications/notification_providers.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/ui/desktop/desktop_scrolling.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_context_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_state_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:chatix/features/chat/presentation/screens/media_preview_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import 'fakes/fake_secure_storage_service.dart';
import 'fakes/fake_web_socket_channel.dart';
import 'pane_frame.dart';

class _MockGetChatUseCase extends Mock implements GetChatUseCase {}

class _MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class _MockGetMessagesContextUseCase extends Mock
    implements GetMessagesContextUseCase {}

class _MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class _MockGetMembersUseCase extends Mock implements GetMembersUseCase {}

class _MockUpdateChatStateUseCase extends Mock
    implements UpdateChatStateUseCase {}

class _MockNotificationService extends Mock implements NotificationService {}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// One of the people in [ChatScreenHarness]'s group.
class HarnessPerson {
  const HarnessPerson(this.id, this.username, this.displayName);

  final int id;
  final String? username;
  final String? displayName;

  ChatProfileEntity get profile => ChatProfileEntity(
    userId: id,
    username: username,
    displayName: displayName,
    avatarUrl: null,
    avatarS3Key: null,
  );

  ChatMemberEntity get member => ChatMemberEntity(
    userId: id,
    roleId: ChatRole.member.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
    profile: profile,
  );
}

/// The real [ChatDetailScreen], in a pane of a given window, over a small
/// group with a short conversation in Russian — no backend anywhere.
///
/// Everything with a server behind it is a mock that answers once; the
/// socket is a fake that never connects. What is left to look at is the
/// screen itself: the feed, the header and the composer with whatever it is
/// showing.
class ChatScreenHarness {
  ChatScreenHarness({this.type = ChatType.group, List<HarnessPerson>? people})
    : people = people ?? defaultPeople;

  static const String chatId = '8d3f1c2a-5b6e-4f70-9a81-b2c3d4e5f607';

  static const UserEntity me = UserEntity(
    id: 7,
    username: 'me',
    email: 'me@example.com',
  );

  static const HarnessPerson myself = HarnessPerson(7, 'me', 'Я');
  static const HarnessPerson ada = HarnessPerson(42, 'ada', 'Ada Lovelace');

  /// A group big enough for "@a" to have a choice to make.
  static const List<HarnessPerson> defaultPeople = [
    myself,
    ada,
    HarnessPerson(43, 'alan.turing', 'Alan Turing'),
    HarnessPerson(44, 'adele', 'Adele Goldberg'),
    HarnessPerson(45, 'grace', 'Grace Hopper'),
    HarnessPerson(46, 'linus', 'Линус Торвальдс'),
  ];

  final ChatType type;
  final List<HarnessPerson> people;

  late final GetChatUseCase getChat;
  late final GetMessagesUseCase getMessages;
  late final GetMessagesContextUseCase getContext;
  late final MarkReadUseCase markRead;
  late final GetMembersUseCase getMembers;

  /// Answers every draft write as the server would: with the text it now
  /// holds and the time it took it.
  late final UpdateChatStateUseCase updateState;
  late final NotificationService notifications;
  late final FakeWebSocketChannel channel;
  late final ChatSocketService socket;

  /// The device-local odds and ends — recent emoji, the keyboard's height —
  /// in memory, so a test can seed them.
  final InMemoryChatLocalPrefsStore prefs = InMemoryChatLocalPrefsStore();

  /// The router of the last [pump] with `routed: true`.
  GoRouter? router;

  /// What `/chats` shows in a routed pump — where closing the chat lands.
  static const String chatsRootLabel = 'chats-root';

  static void setUpAll() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
    registerFallbackValue(
      const MessagesPage(messages: [], nextCursor: null, hasNext: false),
    );
  }

  MessageEntity message(int seq, HarnessPerson author, String content) =>
      MessageEntity(
        id: 'm$seq',
        chatId: chatId,
        seq: seq,
        authorId: author.id,
        type: MessageType.text,
        content: content,
        replyToId: null,
        forwardedFromChatId: null,
        forwardedFromMessageId: null,
        forwardedFromAuthorId: null,
        isEdited: false,
        createdAt: DateTime(2026, 10, 10, 9).add(Duration(minutes: seq)),
        attachments: const [],
        profile: author.profile,
      );

  /// Newest first, as `GET /messages/` answers.
  List<MessageEntity> get messages => [
    message(3, myself, 'Отправлю до обеда'),
    message(2, myself, 'Почти — осталось два раздела'),
    message(1, ada, 'Заметки к релизу готовы?'),
  ];

  ChatEntity chat() => ChatEntity(
    id: chatId,
    seqCounter: 3,
    lastActivityAt: DateTime(2026, 10, 10, 9, 3),
    type: type,
    name: type == ChatType.direct ? null : 'Release crew',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: ada.id,
    memberCount: people.length,
    unreadCount: 0,
    lastRead: ReadDetailEntity(
      lastReadMessageSeq: 3,
      lastReadAt: DateTime(2026, 10, 10, 9, 3),
    ),
    members: [for (final person in people) person.member],
  );

  void setUp() {
    getChat = _MockGetChatUseCase();
    getMessages = _MockGetMessagesUseCase();
    getContext = _MockGetMessagesContextUseCase();
    markRead = _MockMarkReadUseCase();
    getMembers = _MockGetMembersUseCase();
    updateState = _MockUpdateChatStateUseCase();
    notifications = _MockNotificationService();
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
    when(() => notifications.cancelGroup(any())).thenAnswer((_) async {});
    when(() => updateState.setDraft(any(), any())).thenAnswer(
      (invocation) async => Right(
        ChatStateEntity(
          draft: invocation.positionalArguments[1] as String?,
          draftUpdatedAt: DateTime.utc(2026, 10, 10, 12),
        ),
      ),
    );
    when(
      () => getMembers.execute(
        any(),
        limit: any(named: 'limit'),
        includePresence: any(named: 'includePresence'),
      ),
    ).thenAnswer(
      (_) async => Right(
        MembersPage(
          members: [for (final person in people) person.member],
          hasNext: false,
          nextUserId: null,
          presence: const [],
        ),
      ),
    );
    when(() => getChat.execute(chatId)).thenAnswer((_) async => Right(chat()));
    when(
      () => getMessages.execute(chatId, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Right(
        MessagesPage(messages: messages, nextCursor: null, hasNext: false),
      ),
    );
  }

  Future<void> tearDown() async {
    await socket.dispose();
    await channel.dispose();
  }

  /// Mounts the screen.
  ///
  /// With [routed] it sits at `/chats/{id}` under a real [GoRouter], over a
  /// `/chats` page that says [chatsRootLabel] and with an attachment preview
  /// stand-in ([AttachPreviewProbe]) at `/chats/{id}/attach` — for what
  /// needs a route to go to: closing the chat, opening the preview.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    Locale locale = const Locale('ru'),
    List<Override> overrides = const [],
    bool routed = false,
  }) async {
    final container = ProviderContainer(
      // Whatever has no backend here fails once and stays failed, rather
      // than leaving a retry timer behind the test.
      retry: (_, _) => null,
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        getMessagesContextUseCaseProvider.overrideWithValue(getContext),
        markReadUseCaseProvider.overrideWithValue(markRead),
        getMembersUseCaseProvider.overrideWithValue(getMembers),
        updateChatStateUseCaseProvider.overrideWithValue(updateState),
        chatSocketServiceProvider.overrideWithValue(socket),
        notificationServiceProvider.overrideWithValue(notifications),
        authProvider.overrideWith(() => _FakeAuthController(me)),
        chatLocalPrefsStoreProvider.overrideWithValue(prefs),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);

    final appearance = const AppearanceSettings().copyWith(
      wallpaperId: AppWallpaper.plain.id,
    );

    final theme = dark ? AppTheme.dark(appearance) : AppTheme.light(appearance);
    Widget clock(BuildContext context, Widget? child) =>
        AppClock(now: DateTime(2026, 10, 10, 12), child: child!);
    const screen = ChatDetailScreen(chatId: chatId);

    final GoRouter? router;
    if (routed) {
      router = GoRouter(
        initialLocation: const ChatDetailRoute(chatId).location,
        routes: [
          GoRoute(
            path: ChatsRoute.path,
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text(chatsRootLabel))),
            routes: [
              GoRoute(
                path: ChatDetailRoute.path,
                builder: (_, _) => PaneFrame(window: window, child: screen),
                routes: [
                  GoRoute(
                    path: ChatAttachRoute.path,
                    builder: (_, state) => AttachPreviewProbe(
                      args: state.extra as MediaPreviewArgs?,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
    } else {
      router = null;
    }
    this.router = router;

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: container,
        child: router != null
            ? MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: theme,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                scrollBehavior: const AppScrollBehavior(),
                builder: clock,
                routerConfig: router,
              )
            : MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                // The app's own: a desktop pump gets the desktop scrollbars,
                // a phone pump exactly Material's.
                scrollBehavior: const AppScrollBehavior(),
                builder: clock,
                home: PaneFrame(window: window, child: screen),
              ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return container;
  }

  /// Long-presses the bubble that says [text] and picks [action] from its
  /// menu.
  static Future<void> pickFromMenu(
    WidgetTester tester,
    String text,
    String action,
  ) async {
    await tester.longPress(
      find.descendant(
        of: find.byType(MessageBubble),
        matching: find.text(text),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }
}

/// Stands in for the attachment preview at `/chats/{id}/attach`: says what
/// it was handed, so a test can tell the right files arrived.
class AttachPreviewProbe extends StatelessWidget {
  const AttachPreviewProbe({super.key, required this.args});

  final MediaPreviewArgs? args;

  static String labelFor(List<String> names) => 'preview: ${names.join(', ')}';

  @override
  Widget build(BuildContext context) {
    final names = <String>[
      for (final upload in args?.uploads ?? const []) upload.filename,
    ];
    return Scaffold(body: Center(child: Text(labelFor(names))));
  }
}
