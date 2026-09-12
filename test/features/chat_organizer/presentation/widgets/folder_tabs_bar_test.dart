import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/folder_selection_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_tabs_bar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class _FakeChatListController extends ChatListController {
  _FakeChatListController(this._items);

  final List<ChatEntity> _items;

  @override
  Future<ChatListState> build() async => ChatListState(items: _items);
}

void main() {
  final l10n = AppLocalizationsEn();

  ChatEntity chat(
    String id, {
    int unread = 0,
    ChatType type = ChatType.group,
  }) => ChatEntity(
    id: id,
    seqCounter: 1,
    lastActivityAt: DateTime.utc(2026, 3, 10),
    type: type,
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

  Future<ProviderContainer> pumpBar(
    WidgetTester tester, {
    required List<ChatFolder> folders,
    List<ChatEntity> chats = const [],
    double textScale = 1,
    bool dark = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        chatOrganizerDataSourceProvider.overrideWithValue(
          InMemoryChatOrganizerDataSource(
            folders: folders.map(ChatFolderModel.fromEntity).toList(),
          ),
        ),
        chatListProvider.overrideWith(() => _FakeChatListController(chats)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatOrganizerProvider.future);
    await container.read(chatListProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(FolderTabsBar.height),
                child: FolderTabsBar(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    return container;
  }

  testWidgets('every folder gets a tab, after the one that filters nothing', (
    tester,
  ) async {
    await pumpBar(
      tester,
      folders: [
        ChatFolder.fromPreset(FolderPreset.unread),
        ChatFolder.fromPreset(FolderPreset.groups),
      ],
    );

    expect(find.text(l10n.chatFoldersAll), findsOneWidget);
    expect(find.text(l10n.folderPresetUnread), findsOneWidget);
    expect(find.text(l10n.folderPresetGroups), findsOneWidget);
  });

  testWidgets('a tab carries the unread waiting behind it', (tester) async {
    await pumpBar(
      tester,
      folders: [ChatFolder.fromPreset(FolderPreset.unread)],
      chats: [chat('a', unread: 2), chat('b', unread: 3), chat('c')],
    );

    // Five unread across the list, and all five are in the unread folder.
    expect(find.text('5'), findsNWidgets(2));
  });

  testWidgets('tapping a tab is what selects the folder', (tester) async {
    final container = await pumpBar(
      tester,
      folders: [ChatFolder.fromPreset(FolderPreset.channels)],
    );

    expect(container.read(activeFolderProvider), isNull);

    await tester.tap(find.text(l10n.folderPresetChannels));
    await tester.pumpAndSettle();

    expect(
      container.read(activeFolderProvider),
      FolderPreset.channels.folderId,
    );

    await tester.tap(find.text(l10n.chatFoldersAll));
    await tester.pumpAndSettle();

    expect(container.read(activeFolderProvider), isNull);
  });

  testWidgets('the strip holds at a text scale that would burst it', (
    tester,
  ) async {
    await pumpBar(
      tester,
      folders: [
        ChatFolder.fromPreset(FolderPreset.unread),
        ChatFolder.fromPreset(FolderPreset.noReplyFromMe),
      ],
      textScale: 2.4,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the strip is drawn on both grounds', (tester) async {
    await pumpBar(
      tester,
      folders: [ChatFolder.fromPreset(FolderPreset.unread)],
      dark: true,
    );

    expect(tester.takeException(), isNull);
  });
}
