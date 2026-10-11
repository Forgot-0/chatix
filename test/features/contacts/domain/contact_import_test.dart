import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/usecases/import_contacts_use_case.dart';
import 'package:chatix/core/storage/key_value_table.dart';

import '../../../helpers/contacts_fixtures.dart';

void main() {
  group('reading a pasted list', () {
    test('one address per line, a name around it when there is one', () {
      final draft = ContactImportParser.parse('''
Ivan Petrov <ivan@example.com>
anna@example.com
"Мария Иванова" <maria@example.ru>
''');

      expect(draft.entries, const [
        ContactImportEntry(
          email: 'ivan@example.com',
          firstName: 'Ivan',
          lastName: 'Petrov',
        ),
        ContactImportEntry(email: 'anna@example.com'),
        ContactImportEntry(
          email: 'maria@example.ru',
          firstName: 'Мария',
          lastName: 'Иванова',
        ),
      ]);
      expect(draft.rejected, isEmpty);
    });

    test('a comma list on one line gives the addresses alone', () {
      final draft = ContactImportParser.parse('a@x.io, b@y.io; c@z.io');

      expect(
        [for (final e in draft.entries) e.email],
        ['a@x.io', 'b@y.io', 'c@z.io'],
      );
      expect(draft.entries.every((e) => e.firstName == null), isTrue);
    });

    test('the same address twice is sent once, whatever its case', () {
      final draft = ContactImportParser.parse(
        'Ann <ann@x.io>\nANN@X.IO\nann@x.io',
      );

      expect(draft.entries, hasLength(1));
      expect(draft.entries.single.firstName, 'Ann');
    });

    test('lines without an address are set aside, blank ones ignored', () {
      final draft = ContactImportParser.parse('\n\nnot an email\n  \nme@x.io');

      expect(draft.entries, hasLength(1));
      expect(draft.rejected, ['not an email']);
    });

    test('names longer than the server keeps are cut to 64', () {
      final draft = ContactImportParser.parse('${'Я' * 80} <long@x.io>');

      expect(draft.entries.single.firstName, hasLength(64));
    });
  });

  group('importing', () {
    late FakeContactsRemote remote;
    late ImportContactsUseCase useCase;

    List<ContactImportEntry> entries(int count) => [
      for (var i = 0; i < count; i++) ContactImportEntry(email: 'p$i@x.io'),
    ];

    setUp(() {
      remote = FakeContactsRemote();
      useCase = ImportContactsUseCase(
        ContactsRepositoryImpl(
          remote: remote,
          local: KeyValueContactsLocalStore(MemoryKeyValueTable()),
        ),
      );
    });

    test(
      'up to 100 entries is one request, answered with the contacts',
      () async {
        remote.onImport = (batch, key) async => Right(
          ContactImportResult(
            status: ContactImportStatus.done,
            accepted: batch.length,
            matched: 1,
            pending: batch.length - 1,
            contacts: [contact(42, displayName: 'Found')],
          ),
        );

        final result = await useCase.execute(
          entries(100),
          keyFor: (batch) => 'key-${batch.length}',
        );

        expect(remote.imports, hasLength(1));
        expect(remote.imports.single.$2, 'key-100');
        final done = result.getOrElse((_) => throw StateError('failed'));
        expect(done.status, ContactImportStatus.done);
        expect(done.matched, 1);
      },
    );

    test('a long list goes in batches of 500, each with its own key', () async {
      remote.onImport = (batch, key) async => Right(
        ContactImportResult(
          status: ContactImportStatus.queued,
          accepted: batch.length,
        ),
      );

      final keys = <String>[];
      final result = await useCase.execute(
        entries(1200),
        keyFor: (batch) {
          final key = 'k${keys.length}';
          keys.add(key);
          return key;
        },
      );

      expect(
        [for (final call in remote.imports) call.$1.length],
        [500, 500, 200],
      );
      expect([for (final call in remote.imports) call.$2], ['k0', 'k1', 'k2']);
      final queued = result.getOrElse((_) => throw StateError('failed'));
      expect(queued.status, ContactImportStatus.queued);
      expect(queued.accepted, 1200);
    });

    test('stops at the first refusal and says which', () async {
      var calls = 0;
      remote.onImport = (batch, key) async {
        calls++;
        if (calls == 2) {
          return const Left(
            ApiFailure(
              code: 'IDENTIFIER_QUOTA_EXCEEDED',
              message: 'quota',
              detail: {'limit': 5000, 'period': '24h'},
              status: 429,
            ),
          );
        }
        return Right(
          ContactImportResult(
            status: ContactImportStatus.queued,
            accepted: batch.length,
          ),
        );
      };

      final result = await useCase.execute(entries(1500), keyFor: (_) => 'k');

      expect(calls, 2);
      expect(result.getLeft().toNullable(), isA<IdentifierQuotaFailure>());
    });

    test('nothing to send is refused without a request', () async {
      final result = await useCase.execute(const [], keyFor: (_) => 'k');

      expect(result.isLeft(), isTrue);
      expect(remote.imports, isEmpty);
    });
  });
}
