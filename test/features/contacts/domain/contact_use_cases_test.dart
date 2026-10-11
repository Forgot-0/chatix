import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/domain/usecases/contact_use_cases.dart';

import '../../../helpers/contacts_fixtures.dart';

void main() {
  late FakeContactsRemote remote;
  late ContactsRepositoryImpl repository;
  final added = <Map<String, Object?>>[];

  setUp(() {
    added.clear();
    remote = FakeContactsRemote()
      ..onAdd = ({userId, username, firstName, lastName}) async {
        added.add({
          'user_id': userId,
          'username': username,
          'first_name': firstName,
          'last_name': lastName,
        });
        return Right(contact(userId ?? 42, username: username));
      };
    repository = ContactsRepositoryImpl(
      remote: remote,
      local: KeyValueContactsLocalStore(MemoryKeyValueTable()),
    );
  });

  group('adding a contact', () {
    test('by @username: the @ is dropped, blank names are not sent', () async {
      final result = await SaveContactUseCase(
        repository,
      ).execute(username: '  @ivan ', firstName: '  ', lastName: ' Петров ');

      expect(result.isRight(), isTrue);
      expect(added.single, {
        'user_id': null,
        'username': 'ivan',
        'first_name': null,
        'last_name': 'Петров',
      });
    });

    test('by user id, from a profile', () async {
      await SaveContactUseCase(repository).execute(userId: 42);

      expect(added.single['user_id'], 42);
      expect(added.single['username'], isNull);
    });

    test(
      'needs exactly one of the two, or the server would answer 422',
      () async {
        final neither = await SaveContactUseCase(repository).execute();
        final both = await SaveContactUseCase(
          repository,
        ).execute(userId: 1, username: 'x');
        final onlyAt = await SaveContactUseCase(
          repository,
        ).execute(username: '@');

        for (final result in [neither, both, onlyAt]) {
          expect(result.getLeft().toNullable(), isA<InputFailure>());
        }
        expect(added, isEmpty);
      },
    );

    test('a name over 64 characters is refused before it is sent', () async {
      final result = await SaveContactUseCase(
        repository,
      ).execute(username: 'ivan', firstName: 'x' * 65);

      expect(result.getLeft().toNullable(), isA<ContactNameTooLongFailure>());
      expect(added, isEmpty);
    });
  });

  group('renaming', () {
    test('blank halves clear the local name', () async {
      remote.onUpdate = (userId, body) async => Right(contact(userId));

      await EditContactUseCase(
        repository,
      ).rename(1, firstName: ' ', lastName: '');

      expect(remote.updates.single.$2, {'first_name': null, 'last_name': null});
    });
  });

  group('searching', () {
    test('what the server would not search costs no request', () async {
      final useCase = SearchContactsUseCase(repository);

      for (final query in ['', ' ', 'a', '@', '@ ']) {
        final result = await useCase.execute(query);
        expect(result.getOrElse((_) => throw ''), isEmpty, reason: query);
      }
      expect(remote.searches, isEmpty);
    });

    test('@name is sent tight, a prefix as typed', () async {
      final useCase = SearchContactsUseCase(repository);

      await useCase.execute(' @ivan ');
      await useCase.execute('Ив');

      expect(remote.searches, ['@ivan', 'Ив']);
    });

    test('the query rules', () {
      expect(ContactSearchQuery.isSearchable('@i'), isTrue);
      expect(ContactSearchQuery.isSearchable('iv'), isTrue);
      expect(ContactSearchQuery.isSearchable('i'), isFalse);
      expect(ContactSearchQuery.isSearchable('x' * 151), isFalse);
      expect(ContactSearchQuery.stripAt('@@ivan'), 'ivan');
    });
  });
}
