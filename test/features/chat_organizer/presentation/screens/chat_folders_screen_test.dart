import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/chat_organizer/presentation/screens/chat_folders_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  late InMemoryChatOrganizerDataSource store;

  setUp(() => store = InMemoryChatOrganizerDataSource());

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    bool dark = false,
  }) async {
    final container = ProviderContainer(
      overrides: [chatOrganizerDataSourceProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container.read(chatOrganizerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatFoldersScreen(),
        ),
      ),
    );
    await tester.pump();

    return container;
  }

  testWidgets('an account with no folders is told what a folder is', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text(l10n.foldersEmpty), findsOneWidget);
    expect(find.text(l10n.foldersEmptyHint), findsOneWidget);

    // Every preset is on offer, since none has been taken.
    expect(find.text(l10n.folderPresetUnread), findsOneWidget);
    expect(find.text(l10n.folderPresetChannels), findsOneWidget);
  });

  testWidgets('the local-only warning is not buried', (tester) async {
    await pumpScreen(tester);

    expect(find.text(l10n.organizerDeviceOnly), findsOneWidget);
  });

  testWidgets('adding a ready-made folder takes it off the offer', (
    tester,
  ) async {
    final container = await pumpScreen(tester);

    await tester.tap(find.text(l10n.folderPresetGroups));
    await tester.pumpAndSettle();

    final data = container.read(organizerDataProvider);
    expect(data.folders.single.preset, FolderPreset.groups);
    expect(await store.readFolders(), hasLength(1));

    // It now sits under "your folders", with its rules spelled out, and is
    // no longer one of the chips.
    expect(find.text(l10n.folderPresetGroups), findsOneWidget);
    expect(find.textContaining(l10n.chatTypeGroup), findsWidgets);
  });

  testWidgets('the two switches are wired to what they say they are', (
    tester,
  ) async {
    final container = await pumpScreen(tester);

    await tester.tap(find.text(l10n.hideFolderTabs));
    await tester.pumpAndSettle();
    expect(
      container.read(organizerDataProvider).settings.foldersHidden,
      isTrue,
    );

    await tester.tap(find.text(l10n.unarchiveOnNewMessage));
    await tester.pumpAndSettle();
    expect(
      container.read(organizerDataProvider).settings.unarchiveOnNewMessage,
      isFalse,
    );

    expect((await store.readSettings()).foldersHidden, isTrue);
  });

  testWidgets('a folder can be deleted from its row', (tester) async {
    store = InMemoryChatOrganizerDataSource(
      folders: [
        ChatFolderModel.fromEntity(ChatFolder.fromPreset(FolderPreset.unread)),
      ],
    );

    final container = await pumpScreen(tester);
    expect(container.read(organizerDataProvider).folders, hasLength(1));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, l10n.deleteFolder));
    await tester.pumpAndSettle();

    expect(container.read(organizerDataProvider).folders, isEmpty);
  });

  testWidgets('the screen is drawn on both grounds', (tester) async {
    await pumpScreen(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.foldersEmpty), findsOneWidget);

    await pumpScreen(tester);
    expect(tester.takeException(), isNull);
  });
}
