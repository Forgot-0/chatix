import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/leave_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_state_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_header.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';
import '../../../../helpers/pane_frame.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

/// The list, standing still: a leave refreshes it, and there is no server.
class _QuietChatList extends ChatListController {
  @override
  Future<ChatListState> build() async => const ChatListState();

  @override
  Future<void> refresh() async {}
}

class _MockUpdateChatState extends Mock implements UpdateChatStateUseCase {}

/// The direct-chat presence cache, counting how often it is looked at.
class _CountingPresence extends ChatPresenceController {
  final List<String> looks = [];

  @override
  void ensureFresh(String chatId) => looks.add(chatId);
}

class _MockLeaveChat extends Mock implements LeaveChatUseCase {}

/// Presence as `GET /members/?include_presence=true` would report it.
class _FakeGetMembers implements GetMembersUseCase {
  _FakeGetMembers(this._online);

  /// Who is online, per chat.
  final Map<String, Map<int, bool>> _online;

  final List<String> asked = [];

  @override
  Future<Either<Failure, MembersPage>> execute(
    String chatId, {
    int limit = 50,
    int? cursorUserId,
    bool includePresence = false,
  }) async {
    asked.add(chatId);
    final online = _online[chatId] ?? const <int, bool>{};
    return Right(
      MembersPage(
        members: [
          for (final userId in online.keys)
            ChatMemberEntity(
              userId: userId,
              roleId: ChatRole.member.id,
              isMuted: false,
              isBanned: false,
              permissionsOverrides: const {},
            ),
        ],
        hasNext: false,
        nextUserId: null,
        presence: [
          for (final entry in online.entries)
            MemberPresenceEntity(userId: entry.key, isOnline: entry.value),
        ],
      ),
    );
  }

  @override
  Future<Either<Failure, MembersPage>> executeNextPage(
    String chatId,
    MembersPage previous, {
    int limit = 50,
    bool includePresence = false,
  }) => throw UnimplementedError();
}

/// The chat's app bar: who it is with and what they are doing, the face its
/// row in the list has, a call where there is someone to call, and the menu
/// with everything else.
void main() {
  const me = 7;

  ChatProfileEntity profile(int userId, String name) => ChatProfileEntity(
    userId: userId,
    username: name.toLowerCase(),
    displayName: name,
    avatarUrl: null,
    avatarS3Key: null,
  );

  ChatMemberEntity member(int userId, String name, {ChatRole? role}) =>
      ChatMemberEntity(
        userId: userId,
        roleId: (role ?? ChatRole.member).id,
        isMuted: false,
        isBanned: false,
        permissionsOverrides: const {},
        profile: profile(userId, name),
      );

  ChatEntity chat(
    String id,
    ChatType type, {
    String? name,
    ChatProfileEntity? peer,
    required List<ChatMemberEntity> members,
    int? memberCount,
  }) => ChatEntity(
    id: id,
    seqCounter: 1,
    lastActivityAt: DateTime(2026, 3, 2, 10),
    type: type,
    name: name,
    description: null,
    avatarS3Key: null,
    isPublic: type == ChatType.channel,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    // Somebody else's chat, every one of them: leaving is on the table.
    createdBy: 1,
    memberCount: memberCount ?? members.length,
    peer: peer,
    members: members,
  );

  final directOnline = chat(
    'direct-on',
    ChatType.direct,
    peer: profile(42, 'Ada'),
    members: [
      member(me, 'Me', role: ChatRole.direct),
      member(42, 'Ada', role: ChatRole.direct),
    ],
  );

  final directOffline = chat(
    'direct-off',
    ChatType.direct,
    peer: profile(43, 'Grace'),
    members: [
      member(me, 'Me', role: ChatRole.direct),
      member(43, 'Grace', role: ChatRole.direct),
    ],
  );

  // An admin of it, so its menu has everything a group's can have.
  final groupChat = chat(
    'group',
    ChatType.group,
    name: 'Design Team',
    members: [
      member(me, 'Me', role: ChatRole.admin),
      member(42, 'Ada'),
      member(43, 'Grace'),
      member(44, 'Linus'),
    ],
  );

  // The detail endpoint hands a channel's roster over like any other; the
  // header must not turn its subscribers into the channel's face.
  final channelChat = chat(
    'channel',
    ChatType.channel,
    name: 'Release Notes',
    memberCount: 1240,
    members: [
      member(me, 'Me', role: ChatRole.viewer),
      member(42, 'Ada', role: ChatRole.viewer),
      member(43, 'Grace', role: ChatRole.viewer),
    ],
  );

  final chats = [directOnline, directOffline, groupChat, channelChat];

  late FakeWebSocketChannel socketChannel;
  late ChatSocketService socket;
  late _FakeGetMembers getMembers;
  late _MockUpdateChatState updateState;
  late _MockLeaveChat leaveChat;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    socketChannel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => socketChannel,
    );
    getMembers = _FakeGetMembers({
      'direct-on': {me: true, 42: true},
      'direct-off': {me: true, 43: false},
      'group': {me: true, 42: true, 43: false, 44: false},
      'channel': {me: true, 42: true, 43: true},
    });
    updateState = _MockUpdateChatState();
    leaveChat = _MockLeaveChat();

    when(
      () => updateState.mute(any(), until: any(named: 'until')),
    ).thenAnswer((_) async => const Right(ChatStateEntity(isMutedByMe: true)));
    when(
      () => leaveChat.execute(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() async {
    await socket.dispose();
    await socketChannel.dispose();
  });

  Future<ProviderContainer> container({List<Override> extra = const []}) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...extra,
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(_FakeAuthController.new),
        getMembersUseCaseProvider.overrideWithValue(getMembers),
        updateChatStateUseCaseProvider.overrideWithValue(updateState),
        leaveChatUseCaseProvider.overrideWithValue(leaveChat),
        chatListProvider.overrideWith(_QuietChatList.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    return container;
  }

  final searched = <String>[];
  final selecting = <String>[];

  PreferredSizeWidget bar(ChatEntity source, {required bool back}) => AppBar(
    key: ValueKey('bar-${source.id}'),
    automaticallyImplyLeading: false,
    leading: back ? const BackButton() : null,
    titleSpacing: 0,
    title: ChatHeaderTitle(
      chatId: source.id,
      chat: source,
      myUserId: me,
      onTap: () {},
    ),
    actions: [
      ChatHeaderActions(
        chat: source,
        me: source.membershipOf(me),
        onSearch: () => searched.add(source.id),
        onSelectMessages: () => selecting.add(source.id),
      ),
    ],
  );

  Widget app({
    required Widget home,
    required bool dark,
    PaneWindow window = PaneWindow.phone,
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PaneFrame(window: window, child: home),
  );

  /// Every kind of header, one under the other.
  Future<void> pumpAll(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
  }) async {
    final back = !window.hasList;
    final scope = await container();

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: scope,
        child: app(
          dark: dark,
          window: window,
          home: Scaffold(
            body: Column(
              children: [
                for (final source in chats) ...[
                  bar(source, back: back),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpAndSettle();
  }

  /// One chat's screen, as far as its app bar goes.
  Future<void> pumpOne(
    WidgetTester tester,
    ChatEntity source, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    List<Override> extra = const [],
  }) async {
    final scope = await container(extra: extra);

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: scope,
        child: app(
          dark: dark,
          window: window,
          home: Scaffold(
            appBar: bar(source, back: !window.hasList),
            body: const SizedBox.expand(),
          ),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpAndSettle();
  }

  Finder barOf(String chatId) => find.byKey(ValueKey('bar-$chatId'));

  Finder inBar(String chatId, Finder finder) =>
      find.descendant(of: barOf(chatId), matching: finder);

  Finder heroOf(String chatId) => find.byWidgetPredicate(
    (widget) => widget is Hero && widget.tag == chatAvatarHeroTag(chatId),
  );

  Size circleIn(WidgetTester tester, Finder hero) => tester.getSize(
    find
        .descendant(
          of: hero,
          matching: find.byWidgetPredicate(
            (widget) => widget is ClipPath || widget is ClipOval,
          ),
        )
        .first,
  );

  Future<void> openMenu(WidgetTester tester, String chatId) async {
    await tester.tap(inBar(chatId, find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
  }

  group('the name', () {
    Future<List<Override>> book(Map<int, String> localNames) async {
      final store = KeyValueContactsLocalStore(MemoryKeyValueTable());
      await store.save(
        ContactsSnapshot(
          ownerId: me,
          contacts: [
            for (final entry in localNames.entries)
              Contact(
                ownerId: me,
                userId: entry.key,
                firstName: entry.value,
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
          ],
        ),
      );
      return [contactsLocalStoreProvider.overrideWithValue(store)];
    }

    testWidgets('a direct chat goes by the name in the address book', (
      tester,
    ) async {
      await pumpOne(
        tester,
        directOnline,
        extra: await book({42: 'Ада Августа'}),
      );

      expect(inBar('direct-on', find.text('Ада Августа')), findsOneWidget);
      expect(inBar('direct-on', find.text('Ada')), findsNothing);
    });

    testWidgets('a group keeps its own name', (tester) async {
      await pumpOne(tester, groupChat, extra: await book({42: 'Ада'}));

      expect(inBar('group', find.text('Design Team')), findsOneWidget);
    });
  });

  group('the face', () {
    testWidgets('every kind of chat has one, ready to fly', (tester) async {
      await pumpAll(tester);

      for (final source in chats) {
        expect(heroOf(source.id), findsOneWidget, reason: source.id);
        expect(
          circleIn(tester, heroOf(source.id)),
          Size.square(ChatAvatarSize.md.diameter),
          reason: source.id,
        );
      }
    });

    testWidgets('a direct chat shows the person', (tester) async {
      await pumpAll(tester);

      expect(
        find.descendant(of: heroOf('direct-on'), matching: find.text('A')),
        findsOneWidget,
      );
    });

    testWidgets('a group without a picture shows its members', (tester) async {
      await pumpAll(tester);

      expect(
        find.descendant(
          of: heroOf('group'),
          matching: find.byType(ChatAvatarMosaic),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a channel shows its initial, not its subscribers', (
      tester,
    ) async {
      await pumpAll(tester);

      expect(
        find.descendant(
          of: heroOf('channel'),
          matching: find.byType(ChatAvatarMosaic),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: heroOf('channel'), matching: find.text('R')),
        findsOneWidget,
      );
    });
  });

  group('the line under the name', () {
    testWidgets('says "online", in the accent, for a person who is', (
      tester,
    ) async {
      await pumpAll(tester);

      final online = inBar('direct-on', find.text('online'));
      expect(online, findsOneWidget);

      final context = tester.element(online);
      expect(
        tester.widget<Text>(online).style?.color,
        Theme.of(context).colorScheme.primary,
      );
    });

    testWidgets('is not there for a person who is not, and not a handle', (
      tester,
    ) async {
      await pumpAll(tester);

      // The title and the avatar's initial, and nothing else: no "online",
      // no invented "last seen", no @username in its place.
      final texts = tester
          .widgetList<Text>(inBar('direct-off', find.byType(Text)))
          .map((text) => text.data)
          .toList();
      expect(texts, unorderedEquals(['Grace', 'G']));
    });

    testWidgets('counts a group\'s members and who of them is here', (
      tester,
    ) async {
      await pumpAll(tester);

      expect(inBar('group', find.text('4 members, 2 online')), findsOneWidget);
    });

    testWidgets('names a channel\'s audience, grouped for reading', (
      tester,
    ) async {
      await pumpAll(tester);

      expect(inBar('channel', find.text('1,240 subscribers')), findsOneWidget);
    });

    testWidgets('keeps looking while it stays up, and stops when it goes', (
      tester,
    ) async {
      final presence = _CountingPresence();
      await pumpOne(
        tester,
        directOnline,
        extra: [chatPresenceProvider.overrideWith(() => presence)],
      );
      expect(presence.looks, ['direct-on']);

      // Nothing pushes presence (api-docs §6.4), so the header asks again
      // before an answer can go stale; the cache decides what that costs.
      await tester.pump(MemberPresenceCache.ttl);
      expect(presence.looks.length, greaterThanOrEqualTo(3));

      await tester.pumpWidget(const SizedBox());
      final settled = presence.looks.length;
      await tester.pump(MemberPresenceCache.ttl);
      expect(presence.looks.length, settled);
    });

    testWidgets('asks for presence once per chat, and not for a channel', (
      tester,
    ) async {
      await pumpAll(tester);

      expect(
        getMembers.asked,
        unorderedEquals(['direct-on', 'direct-off', 'group']),
      );
    });
  });

  group('the buttons', () {
    testWidgets('a call where there is someone to call, and the menu', (
      tester,
    ) async {
      await pumpAll(tester);

      for (final id in ['direct-on', 'direct-off', 'group']) {
        expect(inBar(id, find.byTooltip('Call')), findsOneWidget, reason: id);
      }
      expect(inBar('channel', find.byTooltip('Call')), findsNothing);

      expect(find.byIcon(Icons.more_vert), findsNWidgets(chats.length));
    });

    testWidgets('search lives in the menu, members in the profile', (
      tester,
    ) async {
      await pumpAll(tester);

      expect(find.byIcon(Icons.search), findsNothing);
      expect(find.byIcon(Icons.people_outline), findsNothing);
    });
  });

  group('the menu', () {
    testWidgets('offers a group admin everything a group has, leave last', (
      tester,
    ) async {
      await pumpOne(tester, groupChat);
      await openMenu(tester, 'group');

      final labels = tester
          .widgetList<PopupMenuItem<Object?>>(
            find.byWidgetPredicate((widget) => widget is PopupMenuItem),
          )
          .map(
            (item) => tester
                .widgetList<Text>(
                  find.descendant(
                    of: find.byWidget(item),
                    matching: find.byType(Text),
                  ),
                )
                .single
                .data,
          )
          .toList();

      expect(labels, [
        'Search',
        'Mute notifications',
        'Pin chat',
        'Archive',
        'Select messages',
        'Manage group',
        'Leave group',
      ]);
      // The way out sits apart from the rest.
      expect(find.byType(PopupMenuDivider), findsOneWidget);
    });

    testWidgets('a direct chat\'s has nothing to manage', (tester) async {
      await pumpOne(tester, directOnline);
      await openMenu(tester, 'direct-on');

      expect(find.text('Manage group'), findsNothing);
      expect(find.text('Leave chat'), findsOneWidget);
    });

    testWidgets('search and selection are handed to the screen', (
      tester,
    ) async {
      searched.clear();
      selecting.clear();
      await pumpOne(tester, groupChat);

      await openMenu(tester, 'group');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      await openMenu(tester, 'group');
      await tester.tap(find.text('Select messages'));
      await tester.pumpAndSettle();

      expect(searched, ['group']);
      expect(selecting, ['group']);
    });

    testWidgets('silencing asks for how long, and sends that deadline', (
      tester,
    ) async {
      await pumpOne(tester, groupChat);
      await openMenu(tester, 'group');

      await tester.tap(find.text('Mute notifications'));
      await tester.pumpAndSettle();

      for (final option in [
        'Mute for 1 hour',
        'Mute for 8 hours',
        'Mute for 2 days',
        'Mute until I turn it back on',
      ]) {
        expect(find.text(option), findsOneWidget, reason: option);
      }

      final before = DateTime.now();
      await tester.tap(find.text('Mute for 2 days'));
      await tester.pumpAndSettle();

      final until =
          verify(
                () => updateState.mute(
                  'group',
                  until: captureAny(named: 'until'),
                ),
              ).captured.single
              as DateTime;
      expect(
        until.difference(before).inMinutes,
        closeTo(const Duration(days: 2).inMinutes, 1),
      );
      expect(find.text('Notifications off for this chat'), findsOneWidget);
    });

    testWidgets('"for good" leaves the far-off date to the use case', (
      tester,
    ) async {
      await pumpOne(tester, groupChat);
      await openMenu(tester, 'group');
      await tester.tap(find.text('Mute notifications'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mute until I turn it back on'));
      await tester.pumpAndSettle();

      verify(() => updateState.mute('group', until: null)).called(1);
    });
  });

  group('leaving from the menu', () {
    Future<GoRouter> pumpRouted(WidgetTester tester) async {
      final scope = await container();
      final router = GoRouter(
        initialLocation: '/chats/group',
        routes: [
          GoRoute(
            path: '/chats',
            builder: (_, _) => const Scaffold(body: Text('the list')),
            routes: [
              GoRoute(
                path: ':chatId',
                builder: (_, _) => Scaffold(
                  appBar: bar(groupChat, back: true),
                  body: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    Finder confirmButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, label),
    );

    testWidgets('asks first, and cancelling leaves nothing done', (
      tester,
    ) async {
      await pumpRouted(tester);
      await openMenu(tester, 'group');

      await tester.tap(find.text('Leave group'));
      await tester.pumpAndSettle();

      expect(
        find.text('Leave this chat? You will stop receiving its messages.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => leaveChat.execute(any()));
      expect(find.text('Design Team'), findsOneWidget);
    });

    testWidgets('confirming leaves, and lands on the list', (tester) async {
      final router = await pumpRouted(tester);
      await openMenu(tester, 'group');

      await tester.tap(find.text('Leave group'));
      await tester.pumpAndSettle();
      await tester.tap(confirmButton('Leave group'));
      await tester.pumpAndSettle();

      verify(() => leaveChat.execute('group')).called(1);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/chats',
      );
      expect(find.text('the list'), findsOneWidget);
    });

    testWidgets('a refusal stays on the chat and says so', (tester) async {
      when(() => leaveChat.execute(any())).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'CHAT_ACCESS_DENIED',
            message: 'Access denied for chat',
            detail: null,
            status: 403,
          ),
        ),
      );
      await pumpRouted(tester);
      await openMenu(tester, 'group');

      await tester.tap(find.text('Leave group'));
      await tester.pumpAndSettle();
      await tester.tap(confirmButton('Leave group'));
      await tester.pumpAndSettle();

      expect(find.text('Design Team'), findsOneWidget);
      expect(
        find.text("You don't have permission to do that."),
        findsOneWidget,
      );
    });
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('chat headers, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pumpAll(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'chat_header_${window.name}_${theme.key}',
          );
        });

        testGoldens('chat menu, ${window.name}, ${theme.key}', (tester) async {
          await pumpOne(tester, groupChat, window: window, dark: theme.value);
          await openMenu(tester, 'group');

          await screenMatchesGolden(
            tester,
            'chat_header_menu_${window.name}_${theme.key}',
          );
        });

        testGoldens('mute durations, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pumpOne(tester, groupChat, window: window, dark: theme.value);
          await openMenu(tester, 'group');
          await tester.tap(find.text('Mute notifications'));
          await tester.pumpAndSettle();

          await screenMatchesGolden(
            tester,
            'chat_header_mute_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
