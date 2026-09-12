import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/data/datasources/search_history_store.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_search_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';
import 'package:chatix/features/chat/presentation/screens/chat_search_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/local_search_notice.dart';
import 'package:chatix/features/chat/presentation/widgets/search_result_tiles.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class MockGetProfilesUseCase extends Mock implements GetProfilesUseCase {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

class _FakeChatListController extends ChatListController {
  _FakeChatListController(this._items);

  final List<ChatEntity> _items;

  @override
  Future<ChatListState> build() async => ChatListState(items: _items);
}

void main() {
  final l10n = AppLocalizationsEn();

  late MockGetProfilesUseCase getProfiles;
  late InMemoryMessageCacheStore cache;
  late InMemorySearchHistoryStore history;

  setUp(() {
    getProfiles = MockGetProfilesUseCase();
    cache = InMemoryMessageCacheStore();
    history = InMemorySearchHistoryStore();

    when(
      () => getProfiles.execute(
        username: any(named: 'username'),
        displayName: any(named: 'displayName'),
        skills: any(named: 'skills'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => const Right(_emptyPage));
  });

  MessageEntity message(String chatId, int seq, String content) =>
      MessageEntity(
        id: '$chatId-$seq',
        chatId: chatId,
        seq: seq,
        authorId: 9,
        type: MessageType.text,
        content: content,
        replyToId: null,
        forwardedFromChatId: null,
        forwardedFromMessageId: null,
        forwardedFromAuthorId: null,
        isEdited: false,
        createdAt: DateTime.utc(2026, 3, 10, seq),
      );

  ChatEntity chat(String id, {String? name, String? description}) => ChatEntity(
    id: id,
    seqCounter: 3,
    lastActivityAt: DateTime.utc(2026, 3, 10),
    type: ChatType.group,
    name: name ?? 'Chat $id',
    description: description,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 2,
  );

  ProfileEntity profile(int id, String name) => ProfileEntity(
    id: id,
    avatars: const {},
    specialization: null,
    displayName: name,
    bio: null,
    dateBirthday: null,
    skills: const [],
    contacts: const [],
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ChatEntity> chats = const [],
    bool dark = false,
  }) async {
    final router = GoRouter(
      initialLocation: ChatSearchRoute.location,
      routes: [
        GoRoute(
          path: ChatsRoute.path,
          builder: (_, _) => const Scaffold(body: Text('chats')),
          routes: [
            GoRoute(
              path: ChatSearchRoute.path,
              builder: (_, _) => const ChatSearchScreen(),
            ),
            GoRoute(
              path: ChatDetailRoute.path,
              builder: (_, _) => const Scaffold(body: Text('chat detail')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          chatListProvider.overrideWith(() => _FakeChatListController(chats)),
          getProfilesUseCaseProvider.overrideWithValue(getProfiles),
          messageCacheStoreProvider.overrideWithValue(cache),
          searchHistoryStoreProvider.overrideWithValue(history),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
  }

  /// Types into the field and lets the debounce run out.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(SearchQueryController.debounce);
    await tester.pumpAndSettle();
  }

  testWidgets('an empty field with no history explains itself', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text(l10n.searchStartTitle), findsOneWidget);
    expect(find.text(l10n.searchStartHint), findsOneWidget);
  });

  testWidgets('an empty field offers what was searched and opened before', (
    tester,
  ) async {
    history = InMemorySearchHistoryStore(
      queries: ['design'],
      chatIds: ['a'],
    );

    await pumpScreen(tester, chats: [chat('a', name: 'Design team')]);

    expect(find.text(l10n.searchRecentQueries.toUpperCase()), findsOneWidget);
    expect(find.text('design'), findsOneWidget);
    expect(find.text(l10n.searchRecentChats.toUpperCase()), findsOneWidget);
    expect(find.text('Design team'), findsOneWidget);
  });

  testWidgets('picking a recent search runs it', (tester) async {
    history = InMemorySearchHistoryStore(queries: ['design']);

    await pumpScreen(tester, chats: [chat('a', name: 'Design team')]);

    await tester.tap(find.text('design'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatSearchResultTile), findsOneWidget);
  });

  testWidgets('the tabs appear once there is something to search for', (
    tester,
  ) async {
    await pumpScreen(tester, chats: [chat('a', name: 'Design team')]);

    expect(find.text(l10n.searchTabMessages), findsNothing);

    await search(tester, 'design');

    expect(find.text(l10n.chats), findsOneWidget);
    expect(find.text(l10n.searchPeople), findsOneWidget);
    expect(find.text(l10n.searchTabMessages), findsOneWidget);
  });

  testWidgets('chats are filtered out of what is already loaded', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      chats: [chat('a', name: 'Design team'), chat('b', name: 'Marketing')],
    );

    await search(tester, 'design');

    expect(find.byType(ChatSearchResultTile), findsOneWidget);
    expect(find.text('Marketing'), findsNothing);
  });

  testWidgets('a query no chat matches says what the tab searches', (
    tester,
  ) async {
    await pumpScreen(tester, chats: [chat('a', name: 'Design team')]);

    await search(tester, 'zzz');

    expect(find.text(l10n.noChatsFound), findsOneWidget);
    expect(find.text(l10n.noChatsFoundHint), findsOneWidget);
  });

  testWidgets('people come from the profiles endpoint', (tester) async {
    when(
      () => getProfiles.execute(
        username: any(named: 'username'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (_) async => Right(
        PageResult<ProfileEntity>(
          items: [profile(9, 'Ann Lee')],
          total: 1,
          page: 1,
          pageSize: 20,
        ),
      ),
    );
    when(
      () => getProfiles.execute(
        displayName: any(named: 'displayName'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => const Right(_emptyPage));

    await pumpScreen(tester);
    await search(tester, 'ann');

    await tester.tap(find.text(l10n.searchPeople));
    await tester.pumpAndSettle();

    expect(find.byType(PersonSearchResultTile), findsOneWidget);
    expect(find.text('Ann Lee'), findsOneWidget);
  });

  testWidgets('a people search that fails offers a retry', (tester) async {
    when(
      () => getProfiles.execute(
        username: any(named: 'username'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure()));
    when(
      () => getProfiles.execute(
        displayName: any(named: 'displayName'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure()));

    await pumpScreen(tester);
    await search(tester, 'ann');

    await tester.tap(find.text(l10n.searchPeople));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
  });

  testWidgets('a people search with no answers says so', (tester) async {
    await pumpScreen(tester);
    await search(tester, 'ann');

    await tester.tap(find.text(l10n.searchPeople));
    await tester.pumpAndSettle();

    expect(find.text(l10n.noPeopleFound), findsOneWidget);
    expect(find.text(l10n.noPeopleFoundHint), findsOneWidget);
  });

  testWidgets('messages are searched on the device, and say so', (
    tester,
  ) async {
    cache.remember('a', [message('a', 3, 'ship it tomorrow')]);

    await pumpScreen(tester, chats: [chat('a', name: 'Design team')]);
    await search(tester, 'ship');

    await tester.tap(find.text(l10n.searchTabMessages));
    await tester.pumpAndSettle();

    expect(find.byType(LocalSearchNotice), findsOneWidget);
    expect(find.text(l10n.searchLoadedHistoryOnly), findsOneWidget);
    expect(find.byType(MessageSearchResultTile), findsOneWidget);
  });

  testWidgets('the newest message of every chat is searchable from cold', (
    tester,
  ) async {
    // `ChatDTO.last_message` arrives with the list, so a preview is
    // searchable before any chat has been opened.
    final withPreview = ChatEntity(
      id: 'a',
      seqCounter: 3,
      lastActivityAt: DateTime.utc(2026, 3, 10),
      type: ChatType.group,
      name: 'Design team',
      description: null,
      avatarS3Key: null,
      isPublic: false,
      adminOnly: false,
      slowModeSeconds: 0,
      permissions: const {},
      createdBy: 1,
      memberCount: 2,
      lastMessage: message('a', 3, 'ship it tomorrow'),
    );

    await pumpScreen(tester, chats: [withPreview]);
    await search(tester, 'ship');

    await tester.tap(find.text(l10n.searchTabMessages));
    await tester.pumpAndSettle();

    expect(find.byType(MessageSearchResultTile), findsOneWidget);
  });

  testWidgets('a message search with nothing to show explains the limit', (
    tester,
  ) async {
    await pumpScreen(tester, chats: [chat('a')]);
    await search(tester, 'ship');

    await tester.tap(find.text(l10n.searchTabMessages));
    await tester.pumpAndSettle();

    expect(find.text(l10n.noMessagesFound), findsOneWidget);
    expect(find.text(l10n.searchLoadedHistoryExplained), findsWidgets);
  });

  testWidgets('opening a result remembers the search that found it', (
    tester,
  ) async {
    await pumpScreen(tester, chats: [chat('a', name: 'Design team')]);
    await search(tester, 'design');

    await tester.tap(find.byType(ChatSearchResultTile));
    await tester.pumpAndSettle();

    expect(history.readQueries(), ['design']);
    expect(history.readChatIds(), ['a']);
  });

  testWidgets('clearing the field brings the history back', (tester) async {
    await pumpScreen(tester, chats: [chat('a', name: 'Design team')]);
    await search(tester, 'design');

    expect(find.byType(ChatSearchResultTile), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text(l10n.searchStartTitle), findsOneWidget);
  });

  testWidgets('the screen is drawn on both grounds', (tester) async {
    await pumpScreen(tester, chats: [chat('a', name: 'Design team')], dark: true);
    await search(tester, 'design');

    expect(tester.takeException(), isNull);
    expect(find.byType(ChatSearchResultTile), findsOneWidget);
  });
}

const PageResult<ProfileEntity> _emptyPage = PageResult<ProfileEntity>(
  items: [],
  total: 0,
  page: 1,
  pageSize: 20,
);
