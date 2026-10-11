import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../helpers/contacts_fixtures.dart';
import '../../../helpers/pane_frame.dart';

class _FakeAuth extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: kOwnerId, username: 'me', email: 'me@x.io');
}

/// Presence as if the member list had already answered.
class _KnownPresence extends ChatPresenceController {
  _KnownPresence(this._online);

  final Map<String, bool> _online;

  @override
  Map<String, bool> build() => _online;

  @override
  void ensureFresh(String chatId) {}
}

class _MockGetProfiles extends Mock implements GetProfilesUseCase {}

ProfileEntity _person(int id, String username, [String? name]) => ProfileEntity(
  id: id,
  username: username,
  avatars: const {},
  specialization: null,
  displayName: name,
  bio: null,
  dateBirthday: null,
  skills: const [],
  contacts: const [],
);

/// The contacts tab: the book, its search, and how both look.
void main() {
  final ru = AppLocalizationsRu();

  final book = [
    contact(1, displayName: 'Анна Смирнова', isFavorite: true, isMutual: true),
    contact(2, displayName: 'Борис Петров', username: 'boris'),
    contact(
      3,
      displayName: 'Ivan Petrov',
      firstName: 'Ваня',
      lastName: 'Работа',
    ),
    contact(4, displayName: 'Ёлка Новогодняя'),
    contact(5, displayName: 'Емельян', isMutual: true),
    contact(6, displayName: 'Anna Schmidt', username: 'anna_s'),
    contact(7, displayName: 'Grace Hopper', isFavorite: true),
    contact(8, username: 'linus'),
    contact(9, displayName: 'Zoe', isMutual: true),
    contact(10, displayName: '42 Pizza', username: 'pizza42'),
  ];

  late FakeContactsRemote remote;
  late _MockGetProfiles getProfiles;

  setUpAll(() => registerFallbackValue(RequestCancellation()));

  setUp(() {
    remote = FakeContactsRemote();
    getProfiles = _MockGetProfiles();
    when(
      () => getProfiles.execute(
        q: any(named: 'q'),
        pageSize: any(named: 'pageSize'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (_) async => Right(
        PageResult<ProfileEntity>(
          items: [
            _person(6, 'anna_s', 'Anna Schmidt'), // already a contact
            _person(30, 'annlee', 'Ann Lee'),
            _person(31, 'annabel'),
          ],
          total: 3,
          page: 1,
          pageSize: 20,
        ),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    List<Contact>? contacts,
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    Locale locale = const Locale('ru'),
    Size? surface,
    bool syncAnswers = true,
  }) async {
    final rows = contacts ?? book;
    final store = KeyValueContactsLocalStore(MemoryKeyValueTable());
    await tester.runAsync(
      () => store.save(
        ContactsSnapshot(ownerId: kOwnerId, contacts: rows, version: 'v1'),
      ),
    );
    // The sync on open answers with the same book.
    if (syncAnswers) remote.onPage = pagesOf(rows, size: 500, version: 'v2');

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        contactsLocalStoreProvider.overrideWithValue(store),
        contactsRepositoryProvider.overrideWith(
          (ref) => ContactsRepositoryImpl(remote: remote, local: store),
        ),
        getProfilesUseCaseProvider.overrideWithValue(getProfiles),
        // Grace has a direct chat, and is here right now.
        directChatIdsProvider.overrideWithValue(const {7: 'chat-grace'}),
        chatPresenceProvider.overrideWith(
          () => _KnownPresence(const {'chat-grace': true}),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Signed in before the tab opens, as in the app: the sync on open has
    // somebody to sync for.
    await tester.runAsync(() => container.read(authProvider.future));

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(window: window, child: const ContactsScreen()),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: surface ?? window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  Finder tileOf(int userId) => find.byKey(ValueKey<int>(userId));

  group('the book', () {
    // Tall enough for the lazy list to build every section.
    const tall = Size(390, 2000);

    testWidgets('favourites first, then Cyrillic, Latin and # for a Russian', (
      tester,
    ) async {
      await pump(tester, surface: tall);

      // Top to bottom, as a reader meets them.
      final headings = [
        ru.contactsFavorites.toUpperCase(),
        'А',
        'Б',
        'В',
        'Е',
        'A',
        'G',
        'L',
        'Z',
        '#',
      ];
      // Headings only — an avatar's initial is the same letter.
      final asHeading = find.byWidgetPredicate(
        (widget) => widget is Semantics && (widget.properties.header ?? false),
      );
      double? last;
      for (final heading in headings) {
        final finder = find.descendant(
          of: asHeading,
          matching: find.text(heading),
        );
        expect(finder, findsOneWidget, reason: heading);
        final top = tester.getTopLeft(finder.first).dy;
        if (last != null) expect(top, greaterThan(last), reason: heading);
        last = top;
      }
    });

    testWidgets('opens on the stored book and syncs behind it', (tester) async {
      await pump(tester);

      expect(remote.pages, hasLength(1));
      expect(
        remote.pages.single.updatedAfter,
        isNull,
        reason: 'no full read yet',
      );
    });

    testWidgets('a contact goes by the name the owner gave', (tester) async {
      await pump(tester);

      expect(find.text('Ваня Работа'), findsOneWidget);
      expect(find.text('Ivan Petrov'), findsNothing);
    });

    testWidgets('online when known, the handle otherwise', (tester) async {
      await pump(tester);

      // Grace is a favourite: her first row is the one under the star.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('favorite-7')),
          matching: find.text(ru.contactsOnline),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tileOf(2), matching: find.text('@boris')),
        findsOneWidget,
      );
    });

    testWidgets('mutual contacts carry the mark, others do not', (
      tester,
    ) async {
      await pump(tester, surface: tall);

      expect(
        find.descendant(
          of: tileOf(9),
          matching: find.byIcon(Icons.people_alt_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tileOf(2),
          matching: find.byIcon(Icons.people_alt_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('a failed refresh is a line over the book, with retry', (
      tester,
    ) async {
      remote.onPage = (_) async => const Left(NetworkFailure());
      await pump(tester, syncAnswers: false);

      expect(find.text(ru.contactsSyncFailed), findsOneWidget);
      expect(tileOf(2), findsOneWidget, reason: 'the book is still there');

      remote.onPage = pagesOf(book, size: 500);
      await tester.tap(find.text(ru.retry));
      await tester.pumpAndSettle();

      expect(find.text(ru.contactsSyncFailed), findsNothing);
    });

    testWidgets('a long press offers the five actions', (tester) async {
      await pump(tester);

      await tester.longPress(tileOf(2));
      await tester.pumpAndSettle();

      for (final label in [
        ru.sendMessageAction,
        ru.contactsActionCall,
        ru.contactsActionFavorite,
        ru.contactsActionRename,
        ru.contactsActionDelete,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('deleting asks first, takes the row and says so', (
      tester,
    ) async {
      await pump(tester);

      await tester.longPress(tileOf(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.contactsActionDelete));
      await tester.pumpAndSettle();
      expect(find.text(ru.contactsDeleteTitle('Борис Петров')), findsOneWidget);

      await tester.tap(find.text(ru.contactsActionDelete).last);
      await tester.pumpAndSettle();

      expect(remote.deletes, [2]);
      expect(tileOf(2), findsNothing);
      expect(find.text(ru.contactsDeleted('Борис Петров')), findsOneWidget);
      // Let the snackbar run out.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('a favourite is listed under the star and under its letter', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Анна Смирнова'), findsNWidgets(2));
      expect(find.byKey(const ValueKey<String>('favorite-1')), findsOneWidget);
      expect(tileOf(1), findsOneWidget);
    });

    testWidgets('an empty book says so and offers the way in', (tester) async {
      await pump(tester, contacts: const []);

      expect(find.text(ru.contactsEmptyTitle), findsOneWidget);
      await tester.tap(find.text(ru.contactsEmptyAction));
      await tester.pumpAndSettle();

      expect(find.text(ru.contactsAddExplain), findsOneWidget);
    });

    testWidgets('adding by a username nobody has says so in place', (
      tester,
    ) async {
      remote.onAdd = ({userId, username, firstName, lastName}) async =>
          const Left(
            ApiFailure(
              code: 'NOT_FOUND_CONTACT_TARGET',
              message: 'nope',
              detail: {'user_id': null, 'username': 'ghost'},
              status: 404,
            ),
          );
      await pump(tester, contacts: const []);

      await tester.tap(find.text(ru.contactsEmptyAction));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, ru.contactsUsernameLabel),
        '@ghost',
      );
      await tester.tap(find.text(ru.contactsAddSubmit));
      await tester.pumpAndSettle();

      expect(find.text(ru.contactsErrorNotFound), findsOneWidget);
      expect(find.text(ru.contactsAddExplain), findsOneWidget);
    });
  });

  group('the search', () {
    testWidgets('answers from the book on the keystroke', (tester) async {
      await pump(tester);

      await type(tester, 'ан');

      expect(find.text(ru.contactsSectionMine.toUpperCase()), findsOneWidget);
      expect(find.byType(ContactTile), findsOneWidget);
      expect(tileOf(1), findsOneWidget);
      expect(remote.searches, isEmpty, reason: 'still within the pause');
      await tester.pump(ContactsScreen.searchDebounce);
    });

    testWidgets('asks the server 300 ms after the last keystroke, once', (
      tester,
    ) async {
      await pump(tester);

      for (final text in ['a', 'an', 'ann']) {
        await type(tester, text);
        await tester.pump(const Duration(milliseconds: 200));
      }
      await type(tester, 'anna');

      await tester.pump(const Duration(milliseconds: 299));
      expect(remote.searches, isEmpty);
      verifyNever(
        () => getProfiles.execute(
          q: any(named: 'q'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(remote.searches, ['anna']);
      verify(
        () => getProfiles.execute(
          q: 'anna',
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).called(1);
    });

    testWidgets('Enter does not wait out the pause', (tester) async {
      await pump(tester);

      await type(tester, 'ann');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(remote.searches, ['ann']);
      await tester.pumpAndSettle();
    });

    testWidgets('people outside the book get a message button', (tester) async {
      await pump(tester);

      await type(tester, 'ann');
      await tester.pump(ContactsScreen.searchDebounce);
      await tester.pumpAndSettle();

      expect(find.text(ru.contactsSectionGlobal.toUpperCase()), findsOneWidget);
      final strangers = find.byType(PersonResultTile);
      expect(strangers, findsNWidgets(2), reason: 'Anna is a contact already');
      expect(
        find.descendant(
          of: strangers.first,
          matching: find.text(ru.sendMessageAction),
        ),
        findsOneWidget,
      );
    });

    testWidgets('clearing the box brings the book back', (tester) async {
      await pump(tester);
      await type(tester, 'ann');
      await tester.pump(ContactsScreen.searchDebounce);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(ru.clear));
      await tester.pumpAndSettle();

      expect(find.text(ru.contactsFavorites.toUpperCase()), findsOneWidget);
      expect(find.byType(PersonResultTile), findsNothing);
    });

    testWidgets('one letter hints at what would search everybody', (
      tester,
    ) async {
      await pump(tester);

      await type(tester, 'z');
      await tester.pump(ContactsScreen.searchDebounce);
      await tester.pumpAndSettle();

      expect(find.text(ru.contactsSearchGlobalHint), findsOneWidget);
      expect(remote.searches, isEmpty);
    });
  });

  group('goldens', () {
    setUp(() => EditableText.debugDeterministicCursor = true);
    tearDown(() => EditableText.debugDeterministicCursor = false);

    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('contacts list, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'contacts_list_${window.name}_${theme.key}',
          );
        });

        testGoldens('contacts search, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);
          await type(tester, 'ann');
          await tester.pump(ContactsScreen.searchDebounce);
          await tester.pumpAndSettle();

          await screenMatchesGolden(
            tester,
            'contacts_search_${window.name}_${theme.key}',
          );
        });

        testGoldens('add contact dialog, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);
          await tester.tap(find.text(ru.contactsAddAction).first);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextField, ru.contactsUsernameLabel),
            'grace',
          );
          await tester.enterText(
            find.widgetWithText(TextField, ru.contactsFirstName),
            'Грейс',
          );
          await tester.pumpAndSettle();

          await screenMatchesGolden(
            tester,
            'contacts_add_dialog_${window.name}_${theme.key}',
          );
        });

        testGoldens('import dialog, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);
          await tester.tap(find.text(ru.contactsImportAction));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField).last,
            'Иван Петров <ivan@example.com>\nanna@example.com\nне адрес',
          );
          await tester.pumpAndSettle();

          await screenMatchesGolden(
            tester,
            'contacts_import_dialog_${window.name}_${theme.key}',
          );
        });

        testGoldens('contacts sync failed, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          remote.onPage = (_) async => const Left(NetworkFailure());
          await pump(
            tester,
            window: window,
            dark: theme.value,
            syncAnswers: false,
          );

          await screenMatchesGolden(
            tester,
            'contacts_sync_failed_${window.name}_${theme.key}',
          );
        });

        testGoldens('contacts empty, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(
            tester,
            contacts: const [],
            window: window,
            dark: theme.value,
          );

          await screenMatchesGolden(
            tester,
            'contacts_empty_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
