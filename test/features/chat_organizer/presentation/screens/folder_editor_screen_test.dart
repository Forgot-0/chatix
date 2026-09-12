import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/chat_organizer/presentation/screens/folder_editor_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  late InMemoryChatOrganizerDataSource store;

  setUp(() => store = InMemoryChatOrganizerDataSource());

  Future<ProviderContainer> pumpEditor(
    WidgetTester tester, {
    String? folderId,
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
          home: FolderEditorScreen(folderId: folderId),
        ),
      ),
    );
    await tester.pump();

    return container;
  }

  Future<void> addChatTypeRule(WidgetTester tester) async {
    await tester.tap(find.text(l10n.addFolderRule));
    await tester.pumpAndSettle();

    // The kind picker, then the editor for the kind that was picked.
    await tester.tap(find.text(l10n.folderRuleChatType));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, l10n.save));
    await tester.pumpAndSettle();
  }

  testWidgets('a new folder starts empty and saves once it has both halves', (
    tester,
  ) async {
    final container = await pumpEditor(tester);

    expect(find.text(l10n.newFolder), findsOneWidget);

    await addChatTypeRule(tester);
    expect(
      find.text(l10n.folderRuleChatTypeIn(l10n.chatTypeDirect)),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Work');
    await tester.tap(find.widgetWithText(TextButton, l10n.save));
    await tester.pumpAndSettle();

    final folder = container.read(organizerDataProvider).folders.single;
    expect(folder.title, 'Work');
    expect(folder.rules, const [
      ChatTypeRule({ChatType.direct}),
    ]);
    expect(await store.readFolders(), hasLength(1));
  });

  testWidgets('saving a nameless folder says so instead of failing quietly', (
    tester,
  ) async {
    final container = await pumpEditor(tester);

    await addChatTypeRule(tester);
    await tester.tap(find.widgetWithText(TextButton, l10n.save));
    await tester.pumpAndSettle();

    expect(find.text(l10n.folderNameRequired), findsOneWidget);
    expect(container.read(organizerDataProvider).folders, isEmpty);
  });

  testWidgets('a folder with no rules is turned away too', (tester) async {
    final container = await pumpEditor(tester);

    await tester.enterText(find.byType(TextField), 'Work');
    await tester.tap(find.widgetWithText(TextButton, l10n.save));
    await tester.pumpAndSettle();

    expect(find.text(l10n.folderRulesRequired), findsOneWidget);
    expect(container.read(organizerDataProvider).folders, isEmpty);
  });

  testWidgets('a rule can be taken back off', (tester) async {
    await pumpEditor(tester);

    await addChatTypeRule(tester);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('editing a preset opens it as an ordinary folder of your own', (
    tester,
  ) async {
    final preset = ChatFolder.fromPreset(FolderPreset.unread);
    store = InMemoryChatOrganizerDataSource(
      folders: [ChatFolderModel.fromEntity(preset)],
    );

    final container = await pumpEditor(tester, folderId: preset.id);

    expect(find.text(l10n.editFolder), findsOneWidget);
    expect(find.text(l10n.folderRuleUnread), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Shouting');
    await tester.tap(find.widgetWithText(TextButton, l10n.save));
    await tester.pumpAndSettle();

    final folder = container.read(organizerDataProvider).folders.single;
    expect(folder.id, preset.id);
    expect(folder.preset, isNull);
    expect(folder.title, 'Shouting');
    expect(folder.rules, const [UnreadRule()]);
  });

  testWidgets('an existing folder can be deleted from the editor', (
    tester,
  ) async {
    final preset = ChatFolder.fromPreset(FolderPreset.channels);
    store = InMemoryChatOrganizerDataSource(
      folders: [ChatFolderModel.fromEntity(preset)],
    );

    final container = await pumpEditor(tester, folderId: preset.id);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, l10n.deleteFolder));
    await tester.pumpAndSettle();

    expect(container.read(organizerDataProvider).folders, isEmpty);
  });

  testWidgets('the editor is drawn on both grounds', (tester) async {
    await pumpEditor(tester, dark: true);
    expect(tester.takeException(), isNull);

    await pumpEditor(tester);
    expect(tester.takeException(), isNull);
  });
}
