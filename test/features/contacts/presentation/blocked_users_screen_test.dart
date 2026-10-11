import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/widgets/app_swipe_actions.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/blocked_users_repository_impl.dart';
import 'package:chatix/features/contacts/presentation/screens/blocked_users_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../helpers/blocked_users_fixtures.dart';
import '../../../helpers/pane_frame.dart';

class _FakeAuth extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@x.io');
}

/// Settings → Privacy → Blocked users: the list by its cursor, the way out
/// of it for each row, and what blocking does today.
void main() {
  final ru = AppLocalizationsRu();

  final people = [
    blockedUser(42, displayName: 'Борис Петров', username: 'boris'),
    blockedUser(43, displayName: 'Grace Hopper', username: 'grace'),
    blockedUser(44, username: 'spam_bot_2000'),
    blockedUser(45, withProfile: false),
  ];

  late FakeBlockedUsersRemote remote;
  late MemoryBlockListLocalStore store;

  setUp(() {
    remote = FakeBlockedUsersRemote(users: people);
    store = MemoryBlockListLocalStore();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
  }) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        blockListLocalStoreProvider.overrideWithValue(store),
        blockedUsersRepositoryProvider.overrideWith(
          (ref) => BlockedUsersRepositoryImpl(remote: remote, local: store),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(authProvider.future));

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(window: window, child: const BlockedUsersScreen()),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> letSnackbarGo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('everybody on the first page, under the honest note', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(ru.blockedUsersNote), findsOneWidget);
    expect(find.text('Борис Петров'), findsOneWidget);
    expect(find.text('@boris'), findsOneWidget);
    // No name: the handle is the title, and is not said twice.
    expect(find.text('@spam_bot_2000'), findsOneWidget);
    expect(find.text(ru.contactsUnknownPerson), findsOneWidget);
    expect(find.text(ru.unblockUserAction), findsNWidgets(people.length));
    expect(remote.pages.single.afterTargetId, isNull);
  });

  testWidgets('the button unblocks, and the row goes', (tester) async {
    await pump(tester);

    await tester.tap(find.text(ru.unblockUserAction).first);
    await tester.pumpAndSettle();

    expect(remote.unblocks, [42]);
    expect(find.text('Борис Петров'), findsNothing);
    expect(find.text(ru.unblockUserDone('Борис Петров')), findsOneWidget);
    await letSnackbarGo(tester);
  });

  testWidgets('a refused unblock brings the row back and says so', (
    tester,
  ) async {
    remote.onUnblock = (_) async => const Left(NetworkFailure());
    await pump(tester);

    await tester.tap(find.text(ru.unblockUserAction).first);
    await tester.pumpAndSettle();

    expect(find.text('Борис Петров'), findsOneWidget);
    expect(find.text(ru.unblockUserDone('Борис Петров')), findsNothing);
    await letSnackbarGo(tester);
  });

  testWidgets('a swipe offers the same way out', (tester) async {
    await pump(tester);

    final row = find.ancestor(
      of: find.text('Grace Hopper'),
      matching: find.byType(AppSwipeActions),
    );
    await tester.drag(find.text('Grace Hopper'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.lock_open_outlined)),
    );
    await tester.pumpAndSettle();

    expect(remote.unblocks, [43]);
    expect(find.text('Grace Hopper'), findsNothing);
    await letSnackbarGo(tester);
  });

  testWidgets('the end of the list asks for the next page by the cursor', (
    tester,
  ) async {
    remote = FakeBlockedUsersRemote(
      users: [for (var id = 100; id < 160; id++) blockedUser(id)],
    );
    await pump(tester);

    await tester.dragUntilVisible(
      find.text('@user159'),
      find.byType(ListView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();

    expect(remote.pages.map((page) => page.afterTargetId), [null, 149]);
    expect(find.text('@user159'), findsOneWidget);
  });

  testWidgets('unblocking the last one leaves the empty state', (tester) async {
    remote = FakeBlockedUsersRemote(users: [blockedUser(42)]);
    await pump(tester);

    await tester.tap(find.text(ru.unblockUserAction));
    await tester.pumpAndSettle();

    expect(find.text(ru.blockedUsersEmptyTitle), findsOneWidget);
    await letSnackbarGo(tester);
  });

  testWidgets('a first page that fails offers to try again', (tester) async {
    remote.onPage = (_) async => const Left(NetworkFailure());
    await pump(tester);

    expect(find.text(ru.retry), findsOneWidget);

    remote.onPage = blockedPagesOf(people);
    await tester.tap(find.text(ru.retry));
    await tester.pumpAndSettle();

    expect(find.text('Борис Петров'), findsOneWidget);
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('blocked users, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'blocked_users_${window.name}_${theme.key}',
          );
        });

        testGoldens('nobody blocked, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          remote = FakeBlockedUsersRemote();
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'blocked_users_empty_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
