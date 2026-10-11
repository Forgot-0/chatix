import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';

import '../../../helpers/contacts_fixtures.dart';

/// `GET /contacts/` is a cursor over `contact_id` with a delta mark that only
/// the last page carries (api-docs §4.8, §0.21). The copy on the device has
/// to come out right through every way that can go.
void main() {
  late FakeContactsRemote remote;
  late KeyValueContactsLocalStore store;
  late DateTime now;
  late ContactsRepositoryImpl repository;

  ContactsRepositoryImpl build({int pageSize = 2}) => ContactsRepositoryImpl(
    remote: remote,
    local: store,
    clock: () => now,
    pageSize: pageSize,
  );

  setUp(() {
    remote = FakeContactsRemote();
    store = KeyValueContactsLocalStore(MemoryKeyValueTable());
    now = DateTime.utc(2026, 10, 11, 12);
    repository = build();
  });

  Future<ContactsSnapshot> sync({bool forceFull = false}) async {
    final result = await repository.sync(
      ownerId: kOwnerId,
      forceFull: forceFull,
    );
    return result.getOrElse((failure) => throw StateError('$failure'));
  }

  List<int> ids(ContactsSnapshot snapshot) =>
      [for (final c in snapshot.contacts) c.userId]..sort();

  group('the first read', () {
    test(
      'follows the cursor to the end and keeps the last page version',
      () async {
        remote.onPage = pagesOf(
          [for (var id = 1; id <= 5; id++) contact(id)],
          size: 2,
          version: '2026-10-11T11:59:00Z',
        );

        final snapshot = await sync();

        expect(ids(snapshot), [1, 2, 3, 4, 5]);
        expect(snapshot.version, '2026-10-11T11:59:00Z');
        expect(snapshot.fullSyncAt, now);
        // after_contact_id walks 2 → 4; nothing filters the first read.
        expect([for (final p in remote.pages) p.afterContactId], [null, 2, 4]);
        expect(remote.pages.every((p) => p.updatedAfter == null), isTrue);
        // And it is on disk for the next launch.
        expect(store.read(), snapshot);
      },
    );

    test('asks for the largest page the server serves', () async {
      repository = ContactsRepositoryImpl(remote: remote, local: store);

      await sync();

      expect(remote.pages.single.limit, 500);
    });

    test('an empty book is still an answer, with a version', () async {
      final snapshot = await sync();

      expect(snapshot.contacts, isEmpty);
      expect(snapshot.version, 'v0');
      expect(store.read(), isNotNull);
    });
  });

  group('the next read is a delta', () {
    setUp(() async {
      remote.onPage = pagesOf(
        [
          contact(1, displayName: 'Ann'),
          contact(2, displayName: 'Bob'),
          contact(3, displayName: 'Cid'),
        ],
        size: 2,
        version: 'v1',
      );
      await sync();
      remote.pages.clear();
    });

    test('sends the stored version as updated_after on every page', () async {
      remote.onPage = (request) async =>
          const Right(ContactPage(contacts: [], hasNext: false, version: 'v2'));

      final snapshot = await sync();

      expect(remote.pages.single.updatedAfter, 'v1');
      expect(snapshot.version, 'v2');
      expect(ids(snapshot), [1, 2, 3], reason: 'nothing changed, all stay');
      // A delta is not a full read: the clock for the next full one keeps
      // running from the first.
      expect(snapshot.fullSyncAt, DateTime.utc(2026, 10, 11, 12));
    });

    test('lays the changed rows over the old ones, by contact_id', () async {
      remote.onPage = (request) async => Right(
        ContactPage(
          contacts: [
            contact(2, displayName: 'Bob', firstName: 'Бобби'),
            contact(4, displayName: 'Dan'),
          ],
          hasNext: false,
          version: 'v2',
        ),
      );

      final snapshot = await sync();

      expect(ids(snapshot), [1, 2, 3, 4]);
      final bob = snapshot.contacts.firstWhere((c) => c.userId == 2);
      expect(bob.localName, 'Бобби');
    });

    test(
      'rows on the version boundary come again and land on themselves',
      () async {
        // `updated_after` is compared with `>=`: the row stamped exactly at v1
        // is sent again, and so is a row repeated across a page edge.
        final again = contact(3, displayName: 'Cid');
        var page = 0;
        remote.onPage = (request) async {
          page++;
          return Right(
            page == 1
                ? ContactPage(
                    contacts: [
                      again,
                      contact(5, displayName: 'Eve'),
                    ],
                    hasNext: true,
                    nextContactId: 5,
                  )
                : ContactPage(
                    contacts: [
                      contact(5, displayName: 'Eve'),
                      again,
                    ],
                    hasNext: false,
                    version: 'v2',
                  ),
          );
        };

        final snapshot = await sync();

        expect(ids(snapshot), [1, 2, 3, 5]);
        expect(snapshot.contacts.where((c) => c.userId == 3), hasLength(1));
        expect(snapshot.contacts.where((c) => c.userId == 5), hasLength(1));
        expect([for (final p in remote.pages) p.updatedAfter], ['v1', 'v1']);
        expect([for (final p in remote.pages) p.afterContactId], [null, 5]);
      },
    );

    test('version only ever comes from the last page', () async {
      // A server that put a mark on a middle page must not have it used:
      // the rows after it would be skipped by the next delta.
      var page = 0;
      remote.onPage = (request) async {
        page++;
        return Right(
          page == 1
              ? ContactPage(
                  contacts: [contact(6)],
                  hasNext: true,
                  nextContactId: 6,
                  version: 'middle',
                )
              : const ContactPage(contacts: [], hasNext: false, version: 'end'),
        );
      };

      final snapshot = await sync();

      expect(snapshot.version, 'end');
    });

    test('a deletion elsewhere stays until the next full read', () async {
      // Deletions never come through a delta (api-docs §4.8).
      remote.onPage = (request) async =>
          const Right(ContactPage(contacts: [], hasNext: false, version: 'v2'));
      expect(ids(await sync()), [1, 2, 3]);

      // Seven days on, the policy reads the whole list again — and 2 is gone.
      now = now.add(ContactSyncPolicy.defaults.fullEvery);
      remote.onPage = pagesOf(
        [contact(1, displayName: 'Ann'), contact(3, displayName: 'Cid')],
        size: 2,
        version: 'v3',
      );
      remote.pages.clear();

      final snapshot = await sync();

      expect(remote.pages.first.updatedAfter, isNull);
      expect(ids(snapshot), [1, 3]);
      expect(snapshot.fullSyncAt, now);
    });

    test('pull-to-refresh forces the full read early', () async {
      remote.onPage = pagesOf([contact(1)], size: 2, version: 'v9');

      final snapshot = await sync(forceFull: true);

      expect(remote.pages.single.updatedAfter, isNull);
      expect(ids(snapshot), [1]);
    });

    test(
      'a last page without a version makes the next sync a full one',
      () async {
        remote.onPage = (request) async =>
            Right(ContactPage(contacts: [contact(9)], hasNext: false));
        await sync(forceFull: true);
        remote.pages.clear();

        remote.onPage = pagesOf([contact(9)], size: 2, version: 'v4');
        await sync();

        expect(remote.pages.single.updatedAfter, isNull);
      },
    );
  });

  group('whose book', () {
    test('a book left by another account is read again from scratch', () async {
      await store.save(
        ContactsSnapshot(
          ownerId: 99,
          contacts: [contact(1, ownerId: 99, firstName: 'Чужое имя')],
          version: 'v-other',
          fullSyncAt: now,
        ),
      );
      remote.onPage = pagesOf([contact(2)], size: 2);

      final snapshot = await sync();

      expect(remote.pages.single.updatedAfter, isNull);
      expect(snapshot.ownerId, kOwnerId);
      expect(ids(snapshot), [2]);
    });
  });

  group('when the read goes wrong', () {
    test('a failure halfway keeps the old copy as it was', () async {
      remote.onPage = pagesOf([contact(1), contact(2)], size: 2, version: 'v1');
      final before = await sync();

      var page = 0;
      remote.onPage = (request) async {
        page++;
        if (page == 1) {
          return Right(
            ContactPage(
              contacts: [contact(3)],
              hasNext: true,
              nextContactId: 3,
            ),
          );
        }
        return const Left(NetworkFailure());
      };

      final result = await repository.sync(ownerId: kOwnerId);

      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(store.read(), before);
    });

    test(
      'a cursor that does not move is given up on, not followed forever',
      () async {
        remote.onPage = (request) async => Right(
          ContactPage(contacts: [contact(1)], hasNext: true, nextContactId: 1),
        );

        final result = await repository.sync(ownerId: kOwnerId);

        expect(result.getLeft().toNullable(), isA<ContactCursorFailure>());
        expect(remote.pages, hasLength(2));
        expect(store.read(), isNull);
      },
    );

    test('has_next without a cursor is given up on too', () async {
      remote.onPage = (request) async =>
          Right(ContactPage(contacts: [contact(1)], hasNext: true));

      final result = await repository.sync(ownerId: kOwnerId);

      expect(result.getLeft().toNullable(), isA<ContactCursorFailure>());
    });

    test('server error codes come back as contact failures', () async {
      remote.onPage = (request) async => const Left(
        ApiFailure(
          code: 'NOT_FOUND_CONTACT',
          message: 'gone',
          detail: {'contact_id': 1},
          status: 404,
        ),
      );

      final result = await repository.sync(ownerId: kOwnerId);

      expect(result.getLeft().toNullable(), isA<ContactNotFoundFailure>());
    });
  });

  group('alongside edits', () {
    test('two syncs asked for at once share one read', () async {
      final gate = Completer<void>();
      remote.onPage = (request) async {
        await gate.future;
        return Right(
          ContactPage(contacts: [contact(1)], hasNext: false, version: 'v1'),
        );
      };

      final first = repository.sync(ownerId: kOwnerId);
      final second = repository.sync(ownerId: kOwnerId);
      gate.complete();
      await Future.wait([first, second]);

      expect(remote.pages, hasLength(1));
    });

    test('a sync for another account waits, then reads its own', () async {
      final gate = Completer<void>();
      remote.onPage = (request) async {
        await gate.future;
        return Right(
          ContactPage(contacts: [contact(1)], hasNext: false, version: 'v1'),
        );
      };

      final mine = repository.sync(ownerId: kOwnerId);
      final theirs = repository.sync(ownerId: 99);
      gate.complete();
      final other = (await theirs).getOrElse((_) => throw StateError(''));
      await mine;

      expect(remote.pages, hasLength(2));
      expect(other.ownerId, 99);
    });

    test(
      'a rename made while the pages were in flight is not undone',
      () async {
        remote.onPage = pagesOf(
          [contact(1), contact(2)],
          size: 2,
          version: 'v1',
        );
        await sync();

        final gate = Completer<void>();
        remote.onPage = (request) async {
          await gate.future;
          // Read before the rename landed: still the old name.
          return Right(
            ContactPage(
              contacts: [contact(1), contact(2)],
              hasNext: false,
              version: 'v2',
            ),
          );
        };
        remote.onUpdate = (userId, body) async =>
            Right(contact(1, firstName: body['first_name'] as String?));

        final syncing = repository.sync(ownerId: kOwnerId, forceFull: true);
        await repository.rename(1, firstName: 'Новое', lastName: null);
        gate.complete();
        final snapshot = (await syncing).getOrElse((_) => throw StateError(''));

        expect(
          snapshot.contacts.firstWhere((c) => c.userId == 1).localName,
          'Новое',
        );
      },
    );

    test(
      'a contact deleted while the pages were in flight stays deleted',
      () async {
        remote.onPage = pagesOf(
          [contact(1), contact(2)],
          size: 2,
          version: 'v1',
        );
        await sync();

        final gate = Completer<void>();
        remote.onPage = (request) async {
          await gate.future;
          return Right(
            ContactPage(
              contacts: [contact(1), contact(2)],
              hasNext: false,
              version: 'v2',
            ),
          );
        };

        final syncing = repository.sync(ownerId: kOwnerId, forceFull: true);
        await repository.remove(2);
        gate.complete();
        final snapshot = (await syncing).getOrElse((_) => throw StateError(''));

        expect(ids(snapshot), [1]);
      },
    );

    test(
      'an edit before a sync does not shadow what the sync brings',
      () async {
        remote.onPage = pagesOf([contact(1)], size: 2, version: 'v1');
        await sync();
        remote.onUpdate = (userId, body) async =>
            Right(contact(1, isFavorite: true));
        await repository.setFavorite(1, true);

        // Later, the server has a newer row for 1 (renamed on another device).
        remote.onPage = (request) async => Right(
          ContactPage(
            contacts: [contact(1, isFavorite: true, firstName: 'Где-то ещё')],
            hasNext: false,
            version: 'v2',
          ),
        );
        final snapshot = await sync();

        expect(snapshot.contacts.single.localName, 'Где-то ещё');
      },
    );
  });

  group('every write goes through to the copy', () {
    setUp(() async {
      remote.onPage = pagesOf([contact(1), contact(2)], size: 2, version: 'v1');
      await sync();
    });

    Contact? stored(int userId) {
      for (final c in store.read()!.contacts) {
        if (c.userId == userId) return c;
      }
      return null;
    }

    test('add', () async {
      remote.onAdd = ({userId, username, firstName, lastName}) async =>
          Right(contact(3, username: username, firstName: firstName));

      await repository.add(username: 'carol', firstName: 'Кэрол');

      expect(stored(3)?.localName, 'Кэрол');
      expect(store.read()!.version, 'v1', reason: 'the mark is not touched');
    });

    test('rename sends both halves, nulls included', () async {
      remote.onUpdate = (userId, body) async => Right(contact(1));

      await repository.rename(1, firstName: 'Аня', lastName: null);

      final (userId, body) = remote.updates.single;
      expect(userId, 1);
      expect(body, {'first_name': 'Аня', 'last_name': null});
    });

    test('favourite sends only is_favorite', () async {
      remote.onUpdate = (userId, body) async =>
          Right(contact(2, isFavorite: true));

      await repository.setFavorite(2, true);

      final (userId, body) = remote.updates.single;
      expect(userId, 2);
      expect(body, {'is_favorite': true});
      expect(stored(2)?.isFavorite, isTrue);
    });

    test('delete, and a delete of someone already gone', () async {
      await repository.remove(1);
      expect(stored(1), isNull);

      remote.onDelete = (userId) async => const Left(
        ApiFailure(
          code: 'NOT_FOUND_CONTACT',
          message: 'gone',
          detail: {'contact_id': 2},
          status: 404,
        ),
      );
      final result = await repository.remove(2);

      expect(result.getLeft().toNullable(), isA<ContactNotFoundFailure>());
      expect(stored(2), isNull, reason: 'the book agrees with the server');
    });

    test('a refused write leaves the copy alone', () async {
      remote.onUpdate = (userId, body) async => const Left(
        ApiFailure(
          code: 'TOO_LONG_CONTACT_NAME',
          message: 'long',
          detail: {'name': '...'},
          status: 400,
        ),
      );
      final before = store.read();

      final result = await repository.rename(1, firstName: 'x', lastName: null);

      expect(result.getLeft().toNullable(), isA<ContactNameTooLongFailure>());
      expect(store.read(), before);
    });
  });
}
