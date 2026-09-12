import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/data/models/organizer_settings_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_tabs_bar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
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

void main() {
  final l10n = AppLocalizationsEn();

  ChatEntity chat(String id, {int unread = 0}) => ChatEntity(
    id: id,
    seqCounter: 3,
    lastActivityAt: DateTime.now(),
    type: ChatType.group,
    name: 'Chat $id',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 2,
    unreadCount: unread,
  );

  late InMemoryChatLocalPrefsStore store;

  setUp(() => store = InMemoryChatLocalPrefsStore());

  Future<void> pumpScreen(
    WidgetTester tester, {
    ChatListState? state = const ChatListState(),
    ChatLocalPrefs prefs = const ChatLocalPrefs(),
    Set<String> pinned = const <String>{},
    Set<String> archived = const <String>{},
    List<ChatFolder> folders = const <ChatFolder>[],
    bool foldersHidden = false,
  }) async {
    for (final flag in ChatLocalFlag.values) {
      await store.writeFlag(flag, prefs.of(flag));
    }

    final router = GoRouter(
      initialLocation: ChatsRoute.location,
      routes: [
        GoRoute(
          path: ChatsRoute.path,
          builder: (_, _) => const ChatsListScreen(),
          routes: [
            GoRoute(
              path: CreateChatRoute.path,
              builder: (_, _) => const Scaffold(body: Text('create')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatLocalPrefsStoreProvider.overrideWithValue(store),
          chatOrganizerDataSourceProvider.overrideWithValue(
            InMemoryChatOrganizerDataSource(
              pinned: pinned,
              archived: archived,
              folders: folders.map(ChatFolderModel.fromEntity).toList(),
              settings: OrganizerSettingsModel(foldersHidden: foldersHidden),
            ),
          ),
          authProvider.overrideWith(_FakeAuthController.new),
          chatListProvider.overrideWith(() => _FakeChatListController(state)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
  }

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
    expect(find.text(l10n.newChat), findsWidgets);
  });

  testWidgets('chats are listed', (tester) async {
    await pumpScreen(
      tester,
      state: ChatListState(items: [chat('a'), chat('b')]),
    );

    expect(find.byType(ChatListTile), findsNWidgets(2));
  });

  testWidgets('pinned chats get their own block at the top', (tester) async {
    await pumpScreen(
      tester,
      state: ChatListState(items: [chat('a'), chat('b')]),
      pinned: const {'b'},
    );

    expect(find.text(l10n.chatPinnedZone.toUpperCase()), findsOneWidget);

    final rows = tester
        .widgetList<ChatListTile>(find.byType(ChatListTile))
        .toList();
    expect(rows.map((row) => row.chat.id), ['b', 'a']);
  });

  testWidgets('archived chats sit behind a lid, closed by default', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      state: ChatListState(items: [chat('a'), chat('b', unread: 2)]),
      archived: const {'b'},
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
    await pumpScreen(
      tester,
      state: ChatListState(items: [chat('a')]),
      archived: const {'a'},
    );

    expect(find.text(l10n.allChatsArchived), findsOneWidget);
    expect(find.text(l10n.noChatsYet), findsNothing);
  });

  testWidgets('more pages to come are announced at the bottom', (
    tester,
  ) async {
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

  testWidgets('the folder strip stays away until there are folders', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      state: ChatListState(items: [chat('a')]),
    );

    expect(find.byType(FolderTabsBar), findsNothing);
  });

  testWidgets('a folder tab narrows the list to what its rules keep', (
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

  testWidgets('a folder that matches nothing says so instead of looking broken', (
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
}
