import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/network/connectivity_providers.dart';
import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/inputs/app_search_pill.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat/presentation/widgets/chats_list_header.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/data/models/organizer_settings_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_tabs_bar.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/notification/presentation/widgets/notification_bell.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

import '../../../../helpers/pane_frame.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async => _me;
}

class _FakeChatListController extends ChatListController {
  _FakeChatListController(this._state);

  final ChatListState? _state;

  @override
  Future<ChatListState> build() async {
    final loaded = _state;
    if (loaded == null) {
      // Never completes: the first-load state the skeleton stands in for.
      return Completer<ChatListState>().future;
    }
    return loaded;
  }
}

class _FakeNotificationBadge extends NotificationBadgeController {
  _FakeNotificationBadge(this._count);

  final int _count;

  @override
  int build() => _count;
}

/// What the socket is doing, and a way to change it mid-test.
class _Socket extends Notifier<ChatSocketStatus> {
  static ChatSocketStatus initial = ChatSocketStatus.ready;

  @override
  ChatSocketStatus build() => initial;

  void report(ChatSocketStatus next) => state = next;
}

final _socketProvider = NotifierProvider<_Socket, ChatSocketStatus>(
  _Socket.new,
);

class _MockGetMembersUseCase extends Mock implements GetMembersUseCase {}

const _myUserId = 7;

/// How long a test finger takes over a scroll.
const _gesture = Duration(milliseconds: 300);
const _me = UserEntity(id: _myUserId, username: 'mira', email: 'm@example.com');

/// A page every route the screen can open lands on, so a tap can be told
/// apart from a tap that did nothing.
class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

void main() {
  final l10n = AppLocalizationsEn();

  // A Saturday noon: stamps read "09:02", "Вчера", a weekday, a date.
  final now = DateTime(2026, 10, 10, 12);

  ChatProfileEntity person(int id, String name) => ChatProfileEntity(
    userId: id,
    username: name.toLowerCase(),
    displayName: name,
    avatarUrl: null,
    avatarS3Key: null,
  );

  MessageEntity message(
    String chatId,
    String content, {
    required int seq,
    int authorId = 12,
    String author = 'Грейс',
    DateTime? at,
  }) => MessageEntity(
    id: '$chatId-m$seq',
    chatId: chatId,
    seq: seq,
    authorId: authorId,
    type: MessageType.text,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: at ?? now,
    profile: person(authorId, author),
  );

  ChatEntity chat(
    String id, {
    String? name,
    ChatType type = ChatType.group,
    int unread = 0,
    bool pinned = false,
    bool archived = false,
    bool muted = false,
    ChatProfileEntity? peer,
    MessageEntity? last,
    DateTime? at,
    int seq = 3,
  }) => ChatEntity(
    id: id,
    seqCounter: seq,
    lastActivityAt: at ?? DateTime.now(),
    type: type,
    name: type == ChatType.direct ? null : (name ?? 'Chat $id'),
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: type == ChatType.direct ? 2 : 5,
    unreadCount: unread,
    lastMessage: last,
    peer: peer,
    state: pinned || archived || muted
        ? ChatStateEntity(
            isPinned: pinned,
            isArchived: archived,
            isMutedByMe: muted,
          )
        : null,
  );

  late InMemoryChatLocalPrefsStore store;
  late _MockGetMembersUseCase getMembers;

  setUp(() {
    store = InMemoryChatLocalPrefsStore();
    getMembers = _MockGetMembersUseCase();
    _Socket.initial = ChatSocketStatus.ready;
  });

  /// Answers presence for every direct chat: online when its id is in
  /// [online], offline otherwise.
  void answerPresence(Set<String> online) {
    when(
      () => getMembers.execute(
        any(),
        limit: any(named: 'limit'),
        includePresence: any(named: 'includePresence'),
      ),
    ).thenAnswer((invocation) async {
      final chatId = invocation.positionalArguments.first as String;
      return Right(
        MembersPage(
          members: const [
            ChatMemberEntity(
              userId: 1000,
              roleId: 4,
              isMuted: false,
              isBanned: false,
              permissionsOverrides: {},
            ),
          ],
          hasNext: false,
          nextUserId: null,
          presence: [
            MemberPresenceEntity(
              userId: 1000,
              isOnline: online.contains(chatId),
            ),
          ],
        ),
      );
    });
  }

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    ChatListState? state = const ChatListState(),
    List<ChatEntity> archived = const <ChatEntity>[],
    List<ChatFolder> folders = const <ChatFolder>[],
    bool foldersHidden = false,
    PaneWindow window = PaneWindow.phone,
    String? selectedChatId,
    bool hasLink = true,
    int alerts = 0,
    Set<String> online = const {},
    List<Contact> contacts = const [],
    bool dark = false,
    Locale? locale,
  }) async {
    tester.view.physicalSize = window.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    answerPresence(online);

    final book = KeyValueContactsLocalStore(MemoryKeyValueTable());
    if (contacts.isNotEmpty) {
      await book.save(ContactsSnapshot(ownerId: _myUserId, contacts: contacts));
    }

    final container = ProviderContainer(
      overrides: [
        chatLocalPrefsStoreProvider.overrideWithValue(store),
        chatOrganizerDataSourceProvider.overrideWithValue(
          InMemoryChatOrganizerDataSource(
            folders: folders.map(ChatFolderModel.fromEntity).toList(),
            settings: OrganizerSettingsModel(foldersHidden: foldersHidden),
          ),
        ),
        contactsLocalStoreProvider.overrideWithValue(book),
        authProvider.overrideWith(_FakeAuthController.new),
        chatListProvider.overrideWith(() => _FakeChatListController(state)),
        // The archive is a second request with its own cursor; the screen
        // asks for it whether or not the drawer is open.
        archivedChatListProvider.overrideWith(
          () => _FakeChatListController(ChatListState(items: archived)),
        ),
        notificationBadgeProvider.overrideWith(
          () => _FakeNotificationBadge(alerts),
        ),
        getMembersUseCaseProvider.overrideWithValue(getMembers),
        chatSocketStateProvider.overrideWith(
          (ref) => ref.watch(_socketProvider),
        ),
        hasNetworkLinkProvider.overrideWithValue(hasLink),
      ],
    );
    addTearDown(container.dispose);

    // Resolved before the first frame, so the rows that ask for presence on
    // mount know who is asking.
    await container.read(authProvider.future);
    await container.read(chatOrganizerProvider.future);

    Widget list(BuildContext context) {
      if (!window.hasList) return const ChatsListScreen();

      final scheme = Theme.of(context).colorScheme;

      // The two panes as the shell draws them: rail, the list at its fixed
      // width, the open chat beside it.
      return AppLayoutScope(
        mode: window.mode,
        child: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: PaneWindow.rail,
                child: ColoredBox(color: scheme.surfaceContainer),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              SizedBox(
                width: AppBreakpoints.listPaneWidth,
                child: ChatsListScreen(selectedChatId: selectedChatId),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: ColoredBox(
                  color: ChatixTheme.of(context).chatBackground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final router = GoRouter(
      initialLocation: ChatsRoute.location,
      routes: [
        GoRoute(
          path: ChatsRoute.path,
          builder: (context, _) => list(context),
          routes: [
            GoRoute(
              path: CreateChatRoute.path,
              builder: (_, _) => const _Probe('create'),
            ),
            GoRoute(
              path: ChatSearchRoute.path,
              builder: (_, _) => const _Probe('search'),
            ),
            GoRoute(
              path: ChatFoldersRoute.path,
              builder: (_, _) => const _Probe('folders'),
            ),
          ],
        ),
        GoRoute(
          path: NotificationsRoute.path,
          builder: (_, _) => const _Probe('notifications'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => AppClock(now: now, child: child!),
        ),
      ),
    );

    // Two frames: the list resolves on the first, and the archive it asks
    // for once it is on screen resolves on the second.
    await tester.pump();
    await tester.pump();

    return container;
  }

  /// Long enough for the title to decide an outage is worth mentioning,
  /// and for the switch to it to finish.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(ChatsListTitle.settleDelay);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder titleText(String text) => find.descendant(
    of: find.byType(ChatsListTitle),
    matching: find.text(text),
  );

  testWidgets('the first load is a skeleton, not a spinner', (tester) async {
    await pumpScreen(tester, state: null);

    expect(find.byType(AppListSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Let the never-completing load go without tripping the timer check.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an account with no chats is invited to start one', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text(l10n.noChatsYet), findsOneWidget);
    expect(find.text(l10n.newChat), findsOneWidget);
    // The header stays: search and the bell are there before any chat is.
    expect(find.byType(AppSearchPill), findsOneWidget);
    expect(find.byType(NotificationBell), findsOneWidget);
  });

  testWidgets('chats are listed', (tester) async {
    await pumpScreen(
      tester,
      state: ChatListState(items: [chat('a'), chat('b')]),
    );

    expect(find.byType(ChatListTile), findsNWidgets(2));
  });

  group('pinned chats', () {
    testWidgets('come first, on their own ground, with no heading', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: ChatListState(items: [chat('a'), chat('b', pinned: true)]),
      );

      final rows = tester
          .widgetList<ChatListTile>(find.byType(ChatListTile))
          .toList();
      expect(rows.map((row) => row.chat.id), ['b', 'a']);

      expect(find.text(l10n.chatPinnedZone.toUpperCase()), findsNothing);
      expect(find.byType(DecoratedSliver), findsOneWidget);
    });

    testWidgets('each carries the pin, unread or not', (tester) async {
      await pumpScreen(
        tester,
        state: ChatListState(
          items: [chat('a', pinned: true, unread: 4), chat('b', pinned: true)],
        ),
      );

      expect(find.byIcon(Icons.push_pin), findsNWidgets(2));
      expect(find.text('4'), findsOneWidget);
    });
  });

  testWidgets('archived chats sit behind a lid, closed by default', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      state: ChatListState(items: [chat('a')]),
      archived: [chat('b', unread: 2, archived: true)],
    );

    expect(find.text(l10n.archivedChats), findsOneWidget);
    expect(find.byType(ChatListTile), findsOneWidget);

    // The lid carries what is waiting inside it.
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text(l10n.archivedChats));
    await tester.pumpAndSettle();

    expect(find.byType(ChatListTile), findsNWidgets(2));
  });

  testWidgets('an account whose every chat is archived says so', (
    tester,
  ) async {
    await pumpScreen(tester, archived: [chat('a', archived: true)]);

    expect(find.text(l10n.allChatsArchived), findsOneWidget);
    expect(find.text(l10n.noChatsYet), findsNothing);
  });

  testWidgets('more pages to come are announced at the bottom', (tester) async {
    await pumpScreen(
      tester,
      state: ChatListState(
        items: [chat('a')],
        hasNext: true,
        nextDate: '2026-01-01T00:00:00Z',
        nextChatId: 'a',
      ),
    );

    expect(find.byType(AppLoadMoreIndicator), findsOneWidget);
  });

  group('folders', () {
    testWidgets('the strip stays away until there are folders', (tester) async {
      await pumpScreen(tester, state: ChatListState(items: [chat('a')]));

      expect(find.byType(FolderTabsBar), findsNothing);
    });

    testWidgets('the strip sits under the search, not over it', (tester) async {
      await pumpScreen(
        tester,
        state: ChatListState(items: [chat('a')]),
        folders: [ChatFolder.fromPreset(FolderPreset.unread)],
      );

      final title = tester.getRect(find.byType(ChatsListTitle));
      final search = tester.getRect(find.byType(AppSearchPill));
      final strip = tester.getRect(find.byType(FolderTabsBar));
      expect(title.bottom, lessThanOrEqualTo(search.top));
      expect(search.bottom, lessThanOrEqualTo(strip.top));
    });

    testWidgets('a tab narrows the list to what its rules keep', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: ChatListState(items: [chat('a'), chat('b', unread: 3)]),
        folders: [ChatFolder.fromPreset(FolderPreset.unread)],
      );

      expect(find.byType(FolderTabsBar), findsOneWidget);
      expect(find.byType(ChatListTile), findsNWidgets(2));

      await tester.tap(find.text(l10n.folderPresetUnread));
      await tester.pumpAndSettle();

      final rows = tester
          .widgetList<ChatListTile>(find.byType(ChatListTile))
          .toList();
      expect(rows.map((row) => row.chat.id), ['b']);
    });

    testWidgets('one that matches nothing says so instead of looking broken', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: ChatListState(items: [chat('a')]),
        folders: [ChatFolder.fromPreset(FolderPreset.channels)],
      );

      await tester.tap(find.text(l10n.folderPresetChannels));
      await tester.pumpAndSettle();

      expect(find.text(l10n.folderEmptyChats), findsOneWidget);
      expect(find.byType(ChatListTile), findsNothing);
    });

    testWidgets('hiding the strip keeps the folders but takes the tabs away', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: ChatListState(items: [chat('a')]),
        folders: [ChatFolder.fromPreset(FolderPreset.unread)],
        foldersHidden: true,
      );

      expect(find.byType(FolderTabsBar), findsNothing);
      expect(find.byType(ChatListTile), findsOneWidget);
    });
  });

  group('the title', () {
    testWidgets('says "Chats" while the list is current', (tester) async {
      await pumpScreen(tester, state: ChatListState(items: [chat('a')]));
      await settle(tester);

      expect(titleText(l10n.chats), findsOneWidget);
      expect(
        tester.getSemantics(titleText(l10n.chats)),
        matchesSemantics(label: l10n.chats, isHeader: true),
      );
    });

    testWidgets('a blink of a reconnect leaves it alone', (tester) async {
      _Socket.initial = ChatSocketStatus.reconnecting;
      await pumpScreen(tester, state: ChatListState(items: [chat('a')]));
      await tester.pump(const Duration(milliseconds: 200));

      expect(titleText(l10n.chats), findsOneWidget);
      expect(titleText(l10n.chatsStatusConnecting), findsNothing);

      // Drain the countdown and the spinner it would have started.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an outage that lasts takes its place: connecting', (
      tester,
    ) async {
      _Socket.initial = ChatSocketStatus.reconnecting;
      await pumpScreen(tester, state: ChatListState(items: [chat('a')]));
      await settle(tester);

      expect(titleText(l10n.chatsStatusConnecting), findsOneWidget);
      expect(titleText(l10n.chats), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('with no network it waits, and does not spin', (tester) async {
      await pumpScreen(
        tester,
        state: ChatListState(items: [chat('a')]),
        hasLink: false,
      );
      await settle(tester);

      expect(titleText(l10n.chatsStatusWaitingForNetwork), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChatsListTitle),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('a list catching up says it is updating', (tester) async {
      await pumpScreen(
        tester,
        state: ChatListState(items: [chat('a')], isCatchingUp: true),
      );
      await settle(tester);

      expect(titleText(l10n.chatsStatusUpdating), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('comes back once the connection does', (tester) async {
      _Socket.initial = ChatSocketStatus.reconnecting;
      final container = await pumpScreen(
        tester,
        state: ChatListState(items: [chat('a')]),
      );
      await settle(tester);
      expect(titleText(l10n.chatsStatusConnecting), findsOneWidget);

      container.read(_socketProvider.notifier).report(ChatSocketStatus.ready);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(titleText(l10n.chats), findsOneWidget);
      expect(titleText(l10n.chatsStatusConnecting), findsNothing);
    });
  });

  group('the search pill', () {
    testWidgets('opens search', (tester) async {
      await pumpScreen(tester, state: ChatListState(items: [chat('a')]));

      await tester.tap(find.byType(AppSearchPill));
      await tester.pumpAndSettle();

      expect(find.text('search'), findsOneWidget);
    });

    testWidgets('gives way on the way down and floats back on the way up', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: ChatListState(items: [for (var i = 0; i < 40; i++) chat('c$i')]),
      );

      final pill = find.byType(AppSearchPill).hitTestable();
      expect(pill, findsOneWidget);

      // Timed, so frames are drawn while the finger moves: the header reads
      // the direction of a scroll in progress, as it does under a real one.
      final list = find.byType(CustomScrollView);
      await tester.timedDrag(list, const Offset(0, -400), _gesture);
      await tester.pumpAndSettle();
      expect(pill, findsNothing);
      // The title and the rest of the header stay.
      expect(titleText(l10n.chats).hitTestable(), findsOneWidget);

      // Up a little, nowhere near the top: the pill is back all the same.
      await tester.timedDrag(list, const Offset(0, 120), _gesture);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CustomScrollView>(list).controller!.offset,
        greaterThan(ChatsListLayout.searchBlockHeight),
      );
      expect(pill, findsOneWidget);
    });
  });

  group('new chat', () {
    testWidgets('a phone gets the round pencil over the list', (tester) async {
      await pumpScreen(tester, state: ChatListState(items: [chat('a')]));

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.shape, const CircleBorder());
      expect(fab.tooltip, l10n.newChat);
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('create'), findsOneWidget);
    });

    testWidgets('two panes put it in the header instead', (tester) async {
      await pumpScreen(
        tester,
        window: PaneWindow.desktop,
        state: ChatListState(items: [chat('a')]),
      );

      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.byTooltip(l10n.newChat));
      await tester.pumpAndSettle();
      expect(find.text('create'), findsOneWidget);
    });
  });

  group('the bell', () {
    testWidgets('carries the unread alerts and opens them', (tester) async {
      await pumpScreen(
        tester,
        state: ChatListState(items: [chat('a')]),
        alerts: 4,
      );

      expect(
        find.descendant(
          of: find.byType(NotificationBell),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip(l10n.unreadNotificationsCount(4)), findsOneWidget);

      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();
      expect(find.text('notifications'), findsOneWidget);
    });
  });

  testWidgets('the open chat is filled, not just hovered, in two panes', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      window: PaneWindow.desktop,
      state: ChatListState(items: [chat('a'), chat('b')]),
      selectedChatId: 'b',
    );

    final scheme = AppTheme.lightTheme.colorScheme;
    Color? fillOf(String id) => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byKey(ValueKey<String>(id)),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;

    expect(fillOf('b'), scheme.primaryContainer);
    expect(fillOf('a'), Colors.transparent);
  });

  group('goldens', () {
    final grace = person(12, 'Грейс');
    final ada = person(11, 'Ada');

    List<ChatEntity> rows() => [
      chat(
        'c1',
        name: 'Поход на Кавказ',
        pinned: true,
        unread: 3,
        seq: 20,
        at: DateTime(2026, 10, 10, 11, 40),
        last: message('c1', '@mira, берёшь палатку?', seq: 20),
      ),
      chat(
        'c2',
        type: ChatType.direct,
        peer: ada,
        pinned: true,
        seq: 9,
        at: DateTime(2026, 10, 10, 9, 2),
        last: message(
          'c2',
          'Созвон в 15:00',
          seq: 9,
          authorId: _myUserId,
          author: 'Мира',
        ),
      ),
      chat(
        'c3',
        name: 'Новости ChatiX',
        type: ChatType.channel,
        muted: true,
        unread: 12,
        at: DateTime(2026, 10, 10, 8, 15),
        last: message('c3', 'Вышла версия 2.4', seq: 3, author: 'ChatiX'),
      ),
      chat(
        'c4',
        type: ChatType.direct,
        peer: person(13, 'Линус'),
        unread: 1,
        at: DateTime(2026, 10, 9, 21, 40),
        last: message('c4', 'Посмотрел PR, всё ок', seq: 3, authorId: 13),
      ),
      chat(
        'c5',
        name: 'Семья',
        at: DateTime(2026, 10, 8, 18, 5),
        last: message('c5', 'Фото с дачи', seq: 3, author: 'Мама'),
      ),
      chat(
        'c6',
        type: ChatType.direct,
        peer: grace,
        at: DateTime(2026, 10, 4, 18, 5),
        last: message('c6', 'До встречи в воскресенье', seq: 3),
      ),
      chat(
        'c7',
        name: 'Архив проекта',
        at: DateTime(2025, 3, 2, 10, 15),
        last: message('c7', 'Итоги года', seq: 3, author: 'Ада'),
      ),
    ];

    // Ada is in the book under the name the reader gave her.
    final contacts = [
      Contact(
        ownerId: _myUserId,
        userId: 11,
        firstName: 'Ада с работы',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        profile: const ContactProfile(id: 11, username: 'ada'),
      ),
    ];

    final folders = [
      ChatFolder.fromPreset(FolderPreset.unread),
      ChatFolder.fromPreset(FolderPreset.personal),
      ChatFolder.fromPreset(FolderPreset.groups),
      ChatFolder.fromPreset(FolderPreset.channels),
    ];

    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final dark in [false, true]) {
        final name = '${window.name}_${dark ? 'dark' : 'light'}';

        Future<void> pumpGolden(
          WidgetTester tester, {
          List<ChatEntity>? items,
          List<ChatFolder> withFolders = const [],
          bool hasLink = true,
        }) async {
          await pumpScreen(
            tester,
            window: window,
            dark: dark,
            locale: const Locale('ru'),
            state: ChatListState(
              items: items ?? rows(),
              peerReadSeqs: {'c2': 9},
            ),
            folders: withFolders,
            hasLink: hasLink,
            alerts: 3,
            online: const {'c2'},
            contacts: contacts,
            selectedChatId: window.hasList ? 'c2' : null,
          );
          await settle(tester);
        }

        testWidgets('the list, $name', (tester) async {
          await pumpGolden(tester);

          // Ada's row: the reader's name for her, her dot, the pin.
          expect(find.text('Ада с работы'), findsOneWidget);
          expect(find.byType(MentionBadge), findsOneWidget);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/chats_list_normal_$name.png'),
          );
        });

        testWidgets('with folders, $name', (tester) async {
          await pumpGolden(tester, withFolders: folders);

          expect(find.byType(FolderTabsBar), findsOneWidget);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/chats_list_folders_$name.png'),
          );
        });

        testWidgets('without a network, $name', (tester) async {
          await pumpGolden(tester, hasLink: false);

          expect(find.text('Ожидание сети…'), findsOneWidget);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/chats_list_offline_$name.png'),
          );
        });

        testWidgets('empty, $name', (tester) async {
          await pumpGolden(tester, items: const []);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/chats_list_empty_$name.png'),
          );
        });
      }
    }
  });
}
