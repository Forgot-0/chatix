import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/contacts/presentation/providers/contact_search_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

import '../../../helpers/contacts_fixtures.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;

  void signOut() => state = const AsyncValue.data(null);
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

void main() {
  const me = UserEntity(id: kOwnerId, username: 'me', email: 'me@x.io');

  late FakeContactsRemote remote;
  late KeyValueContactsLocalStore store;
  late _MockGetProfiles getProfiles;
  late _FakeAuth auth;

  setUpAll(() => registerFallbackValue(RequestCancellation()));

  setUp(() {
    remote = FakeContactsRemote();
    store = KeyValueContactsLocalStore(MemoryKeyValueTable());
    getProfiles = _MockGetProfiles();
    when(
      () => getProfiles.execute(
        q: any(named: 'q'),
        pageSize: any(named: 'pageSize'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        PageResult<ProfileEntity>(items: [], total: 0, page: 1, pageSize: 20),
      ),
    );
  });

  Future<ProviderContainer> container({
    UserEntity? user = me,
    Stream<WSEvent>? socket,
  }) async {
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => auth = _FakeAuth(user)),
        contactsLocalStoreProvider.overrideWithValue(store),
        contactsRepositoryProvider.overrideWith(
          (ref) => ContactsRepositoryImpl(remote: remote, local: store),
        ),
        getProfilesUseCaseProvider.overrideWithValue(getProfiles),
        chatSocketEventsProvider.overrideWith(
          (ref) => socket ?? const Stream<WSEvent>.empty(),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    return c;
  }

  group('the book', () {
    test('opens on the stored copy, without asking anybody', () async {
      await store.save(
        ContactsSnapshot(
          ownerId: kOwnerId,
          contacts: [contact(1, displayName: 'Ivan', firstName: 'Ваня')],
          version: 'v1',
        ),
      );
      final c = await container();

      final state = c.read(contactsProvider);

      expect(state.isStored, isTrue);
      expect(state.book.length, 1);
      expect(c.read(contactLocalNameProvider(1)), 'Ваня');
      expect(remote.pages, isEmpty);
    });

    test('nothing stored is "not known yet", until a sync answers', () async {
      remote.onPage = pagesOf([contact(1)], size: 10);
      final c = await container();

      expect(c.read(contactsProvider).isStored, isFalse);
      final syncing = c.read(contactsProvider.notifier).sync();
      expect(c.read(contactsProvider).isFirstLoad, isTrue);
      await syncing;

      expect(c.read(contactsProvider).isStored, isTrue);
      expect(c.read(contactsProvider).book.contains(1), isTrue);
    });

    test('a failed sync keeps the book it had and says why', () async {
      await store.save(
        ContactsSnapshot(ownerId: kOwnerId, contacts: [contact(1)]),
      );
      remote.onPage = (_) async => const Left(NetworkFailure());
      final c = await container();

      await c.read(contactsProvider.notifier).sync();

      final state = c.read(contactsProvider);
      expect(state.book.contains(1), isTrue);
      expect(state.failure, isA<NetworkFailure>());
      expect(state.isSyncing, isFalse);
    });

    test('a star shows at once and goes back if the server says no', () async {
      await store.save(
        ContactsSnapshot(ownerId: kOwnerId, contacts: [contact(1)]),
      );
      final answer = Completer<void>();
      remote.onUpdate = (userId, body) async {
        await answer.future;
        return const Left(ServerFailure(message: 'no'));
      };
      final c = await container();

      final pending = c.read(contactsProvider.notifier).setFavorite(1, true);
      expect(c.read(contactsProvider).book[1]?.isFavorite, isTrue);

      answer.complete();
      await pending;
      expect(c.read(contactsProvider).book[1]?.isFavorite, isFalse);
    });

    test('a deleted row goes at once, and comes back if refused', () async {
      await store.save(
        ContactsSnapshot(ownerId: kOwnerId, contacts: [contact(1), contact(2)]),
      );
      remote.onDelete = (userId) async => const Left(NetworkFailure());
      final c = await container();

      final pending = c.read(contactsProvider.notifier).remove(1);
      expect(c.read(contactsProvider).book.contains(1), isFalse);
      await pending;

      expect(c.read(contactsProvider).book.contains(1), isTrue);
    });

    test('a local name set here reaches the chat list at once', () async {
      await store.save(
        ContactsSnapshot(ownerId: kOwnerId, contacts: [contact(1)]),
      );
      remote.onUpdate = (userId, body) async =>
          Right(contact(1, firstName: body['first_name'] as String?));
      final c = await container();
      final names = <String?>[];
      c.listen(
        contactLocalNameProvider(1),
        (_, next) => names.add(next),
        fireImmediately: true,
      );

      await c.read(contactsProvider.notifier).rename(1, firstName: 'Мама');
      // Dependents are rebuilt on the container's next flush.
      await pumpEventQueue();

      expect(names, [null, 'Мама']);
    });
  });

  group('the session around it', () {
    test('signing out forgets the book', () async {
      await store.save(
        ContactsSnapshot(ownerId: kOwnerId, contacts: [contact(1)]),
      );
      final c = await container();
      c.listen(contactsLifecycleProvider, (_, _) {});
      await pumpEventQueue();

      auth.signOut();
      await pumpEventQueue();

      expect(c.read(contactsProvider).book.isEmpty, isTrue);
      expect(store.read(), isNull);
    });

    test('signing out while a sync reads keeps nothing it brings', () async {
      final gate = Completer<void>();
      remote.onPage = (request) async {
        await gate.future;
        return Right(
          ContactPage(
            contacts: [contact(1, firstName: 'Тайное имя')],
            hasNext: false,
            version: 'v1',
          ),
        );
      };
      final c = await container();
      c.listen(contactsLifecycleProvider, (_, _) {});
      await pumpEventQueue();

      auth.signOut();
      await pumpEventQueue();
      gate.complete();
      await pumpEventQueue();

      expect(c.read(contactsProvider).book.isEmpty, isTrue);
      expect(store.read(), isNull);
    });

    test('a signed-in launch syncs straight away', () async {
      remote.onPage = pagesOf([contact(5)], size: 10);
      final c = await container();

      c.listen(contactsLifecycleProvider, (_, _) {});
      await pumpEventQueue();

      expect(remote.pages, hasLength(1));
      expect(c.read(contactsProvider).book.contains(5), isTrue);
    });

    test('a finished import syncs and leaves its counts to be shown', () async {
      final socket = StreamController<WSEvent>.broadcast();
      addTearDown(socket.close);
      remote.onPage = pagesOf([contact(5)], size: 10);
      final c = await container(socket: socket.stream);
      c.listen(contactsLifecycleProvider, (_, _) {});
      // Keep the event stream subscribed.
      c.listen(chatSocketEventsProvider, (_, _) {});
      await pumpEventQueue();
      remote.pages.clear();

      socket.add(
        const ContactsImportCompleted(
          ownerId: kOwnerId,
          accepted: 120,
          matched: 3,
          pending: 117,
          invalid: 0,
        ),
      );
      await pumpEventQueue();

      expect(remote.pages, hasLength(1));
      expect(
        c.read(contactImportReportProvider),
        const ContactImportReport(
          ownerId: kOwnerId,
          accepted: 120,
          matched: 3,
          pending: 117,
          invalid: 0,
        ),
      );
    });

    test('somebody else\'s import report is ignored', () async {
      final socket = StreamController<WSEvent>.broadcast();
      addTearDown(socket.close);
      final c = await container(socket: socket.stream);
      c.listen(contactsLifecycleProvider, (_, _) {});
      c.listen(chatSocketEventsProvider, (_, _) {});
      await pumpEventQueue();

      socket.add(
        const ContactsImportCompleted(
          ownerId: 99,
          accepted: 1,
          matched: 1,
          pending: 0,
          invalid: 0,
        ),
      );
      await pumpEventQueue();

      expect(c.read(contactImportReportProvider), isNull);
    });
  });

  group('the search', () {
    Future<ProviderContainer> searching() async {
      await store.save(
        ContactsSnapshot(
          ownerId: kOwnerId,
          contacts: [
            contact(1, displayName: 'Ivan Petrov', username: 'ivan'),
            contact(2, displayName: 'Anna', username: 'anna'),
          ],
        ),
      );
      final c = await container();
      c.listen(contactSearchProvider, (_, _) {});
      return c;
    }

    test(
      'answers from the book on the keystroke, before any request',
      () async {
        final c = await searching();

        c
            .read(contactSearchProvider.notifier)
            .setQuery('iv', languageCode: 'en');

        final state = c.read(contactSearchProvider);
        expect([for (final x in state.mine) x.userId], [1]);
        expect(state.isLoading, isTrue);
        expect(remote.searches, isEmpty);
      },
    );

    test('one letter is local only: nothing would be sent', () async {
      final c = await searching();

      c.read(contactSearchProvider.notifier).setQuery('a', languageCode: 'en');
      await c.read(contactSearchProvider.notifier).searchRemote();

      expect(c.read(contactSearchProvider).isLoading, isFalse);
      expect(remote.searches, isEmpty);
      verifyNever(
        () => getProfiles.execute(
          q: any(named: 'q'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      );
    });

    test('lays the server answers in the two sections', () async {
      final c = await searching();
      remote.onSearch = (query) async => Right([
        // In the book on the server, not yet in this copy.
        ContactSearchHit(
          userId: 3,
          profile: const ContactProfile(id: 3, username: 'ivanna'),
          contact: contact(3, username: 'ivanna'),
        ),
        // Already shown from the copy: not twice.
        ContactSearchHit(userId: 1, contact: contact(1, username: 'ivan')),
      ]);
      when(
        () => getProfiles.execute(
          q: 'iv',
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer(
        (_) async => Right(
          PageResult<ProfileEntity>(
            items: [
              _person(1, 'ivan', 'Ivan Petrov'), // a contact
              _person(kOwnerId, 'me'), // me
              _person(40, 'ivo', 'Ivo Stranger'),
            ],
            total: 3,
            page: 1,
            pageSize: 20,
          ),
        ),
      );

      c.read(contactSearchProvider.notifier).setQuery('iv', languageCode: 'en');
      await c.read(contactSearchProvider.notifier).searchRemote();

      final state = c.read(contactSearchProvider);
      expect([for (final x in state.mine) x.userId], [1, 3]);
      expect([for (final x in state.global) x.userId], [40]);
      expect(state.isLoading, isFalse);
      expect(remote.searches, ['iv']);
    });

    test('@name puts the exact hit first in the global section', () async {
      final c = await searching();
      remote.onSearch = (query) async => const Right([
        ContactSearchHit(
          userId: 77,
          profile: ContactProfile(id: 77, username: 'boris'),
        ),
      ]);
      when(
        () => getProfiles.execute(
          q: 'boris',
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer(
        (_) async => Right(
          PageResult<ProfileEntity>(
            items: [_person(78, 'borislav'), _person(77, 'boris')],
            total: 2,
            page: 1,
            pageSize: 20,
          ),
        ),
      );

      c
          .read(contactSearchProvider.notifier)
          .setQuery('@boris', languageCode: 'en');
      await c.read(contactSearchProvider.notifier).searchRemote();

      final state = c.read(contactSearchProvider);
      expect(remote.searches, ['@boris']);
      expect([for (final x in state.global) x.userId], [77, 78]);
    });

    test('an answer to an older query is dropped', () async {
      final c = await searching();
      final slow = Completer<void>();
      remote.onSearch = (query) async {
        if (query == 'iv') await slow.future;
        return const Right([
          ContactSearchHit(
            userId: 50,
            profile: ContactProfile(id: 50, username: 'late'),
          ),
        ]);
      };

      final notifier = c.read(contactSearchProvider.notifier);
      notifier.setQuery('iv', languageCode: 'en');
      final old = notifier.searchRemote();
      notifier.setQuery('an', languageCode: 'en');
      slow.complete();
      await old;

      final state = c.read(contactSearchProvider);
      expect(state.query, 'an');
      expect(state.global, isEmpty, reason: 'the "iv" answer arrived late');
    });

    test('a failure shows only when nothing came back at all', () async {
      final c = await searching();
      remote.onSearch = (_) async => const Left(NetworkFailure());
      when(
        () => getProfiles.execute(
          q: any(named: 'q'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const Left(NetworkFailure()));

      c.read(contactSearchProvider.notifier).setQuery('zz', languageCode: 'en');
      await c.read(contactSearchProvider.notifier).searchRemote();

      expect(c.read(contactSearchProvider).failure, isA<NetworkFailure>());
    });

    test('stays within /profiles/ twenty a minute', () async {
      final c = await searching();
      final notifier = c.read(contactSearchProvider.notifier);

      for (var i = 0; i < 21; i++) {
        notifier.setQuery('q$i', languageCode: 'en');
        await notifier.searchRemote();
      }

      verify(
        () => getProfiles.execute(
          q: any(named: 'q'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).called(20);
      // The book search still went out every time.
      expect(remote.searches, hasLength(21));
    });
  });
}
