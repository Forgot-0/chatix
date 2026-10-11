import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/chat_composer.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_locked_notice.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/blocked_users_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../../helpers/blocked_users_fixtures.dart';
import '../../../../helpers/chat_screen_harness.dart';
import '../../../../helpers/pane_frame.dart';

/// A direct chat with somebody the reader blocked: no composer, a bar that
/// says so and lifts it. The server would still take a message (api-docs
/// §4.13, "этап 2") — this is the client's half of a block.
void main() {
  setUpAll(ChatScreenHarness.setUpAll);

  final ru = AppLocalizationsRu();
  const ada = ChatScreenHarness.ada;

  late ChatScreenHarness harness;
  late FakeBlockedUsersRemote remote;
  late MemoryBlockListLocalStore store;

  setUp(() {
    harness = ChatScreenHarness(
      type: ChatType.direct,
      people: const [ChatScreenHarness.myself, ada],
    )..setUp();
    remote = FakeBlockedUsersRemote();
    store = MemoryBlockListLocalStore();
  });

  tearDown(() => harness.tearDown());

  Future<void> pump(
    WidgetTester tester, {
    bool blocked = true,
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
  }) async {
    if (blocked) {
      await store.save(
        BlockList(ownerId: ChatScreenHarness.me.id, userIds: {ada.id}),
      );
    }
    await harness.pump(
      tester,
      window: window,
      dark: dark,
      overrides: [
        blockListLocalStoreProvider.overrideWithValue(store),
        blockedUsersRepositoryProvider.overrideWith(
          (ref) => BlockedUsersRepositoryImpl(remote: remote, local: store),
        ),
      ],
    );
  }

  /// The snackbar's timer must run out before the test ends.
  Future<void> letSnackbarGo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('blocked: the bar instead of the composer', (tester) async {
    await pump(tester);

    expect(find.text(ru.blockedChatNotice), findsOneWidget);
    expect(find.text(ru.unblockUserAction), findsOneWidget);
    expect(find.byType(ChatComposer), findsNothing);
    // The conversation itself is still there to read.
    expect(find.text('Заметки к релизу готовы?'), findsOneWidget);
  });

  testWidgets('not blocked: the composer, and no bar', (tester) async {
    await pump(tester, blocked: false);

    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.byType(ComposerLockedNotice), findsNothing);
  });

  testWidgets('"Unblock" on the bar gives the composer back', (tester) async {
    await pump(tester);

    await tester.tap(find.text(ru.unblockUserAction));
    await tester.pumpAndSettle();

    expect(remote.unblocks, [ada.id]);
    expect(store.read()?.userIds, isEmpty);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.text(ru.unblockUserDone('Ada Lovelace')), findsOneWidget);
    await letSnackbarGo(tester);
  });

  testWidgets('the "⋮" blocks, after saying what that does', (tester) async {
    await pump(tester, blocked: false);

    await openMenu(tester);
    await tester.tap(find.text(ru.blockUserAction));
    await tester.pumpAndSettle();

    expect(find.text(ru.blockUserTitle('Ada Lovelace')), findsOneWidget);
    expect(find.text(ru.blockUserMessage), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, ru.blockUserConfirm));
    await tester.pumpAndSettle();

    expect(remote.blocks, [ada.id]);
    expect(find.byType(ChatComposer), findsNothing);
    expect(find.text(ru.blockedChatNotice), findsOneWidget);
    await letSnackbarGo(tester);
  });

  testWidgets('cancelling the dialog blocks nobody', (tester) async {
    await pump(tester, blocked: false);

    await openMenu(tester);
    await tester.tap(find.text(ru.blockUserAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ru.cancel));
    await tester.pumpAndSettle();

    expect(remote.blocks, isEmpty);
    expect(find.byType(ChatComposer), findsOneWidget);
  });

  testWidgets('once blocked, the "⋮" offers the way back', (tester) async {
    await pump(tester);

    await openMenu(tester);

    expect(find.text(ru.unblockUserAction), findsNWidgets(2));
    expect(find.text(ru.blockUserAction), findsNothing);
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('blocked bar, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'chat_blocked_peer_${window.name}_${theme.key}',
          );
        });

        testGoldens('direct chat menu, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, blocked: false, window: window, dark: theme.value);
          await openMenu(tester);

          await screenMatchesGolden(
            tester,
            'chat_direct_menu_${window.name}_${theme.key}',
          );
        });

        testGoldens('block dialog, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, blocked: false, window: window, dark: theme.value);
          await openMenu(tester);
          await tester.tap(find.text(ru.blockUserAction));
          await tester.pumpAndSettle();

          await screenMatchesGolden(
            tester,
            'chat_block_dialog_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
