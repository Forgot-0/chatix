import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';

import '../../../helpers/contacts_fixtures.dart';

/// A table that counts its writes, to see that a delta stays small.
class _CountingTable extends MemoryKeyValueTable {
  final List<String> written = <String>[];
  final List<String> deleted = <String>[];

  @override
  Future<void> writeAll(Map<String, String> entries) {
    written.addAll(entries.keys);
    return super.writeAll(entries);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) {
    deleted.addAll(keys);
    return super.deleteAll(keys);
  }
}

void main() {
  late _CountingTable table;

  setUp(() => table = _CountingTable());

  ContactsSnapshot snapshot(List<Contact> contacts, {int owner = kOwnerId}) =>
      ContactsSnapshot(
        ownerId: owner,
        contacts: contacts,
        version: '2026-10-11T12:00:00Z',
        fullSyncAt: DateTime.utc(2026, 10, 11, 12),
      );

  test('what is saved reads back identically after a restart', () async {
    final saved = snapshot([
      contact(1, displayName: 'Ann', firstName: 'Аня', isFavorite: true),
      contact(2, username: 'bob', isMutual: true),
      contact(3, withProfile: false, lastName: 'Без профиля'),
    ]);
    await KeyValueContactsLocalStore(table).save(saved);

    // A new store over the same table: what the next launch sees.
    final restored = KeyValueContactsLocalStore(table).read();

    expect(restored?.ownerId, saved.ownerId);
    expect(restored?.version, saved.version);
    expect(restored?.fullSyncAt, saved.fullSyncAt);
    expect(
      {for (final c in restored!.contacts) c.userId: c},
      {for (final c in saved.contacts) c.userId: c},
    );
  });

  test('nothing stored reads as null, not as an empty book', () {
    expect(KeyValueContactsLocalStore(table).read(), isNull);
  });

  test('a save writes only the rows that changed', () async {
    final store = KeyValueContactsLocalStore(table);
    await store.save(snapshot([contact(1), contact(2), contact(3)]));
    table.written.clear();

    await store.save(
      snapshot([contact(1), contact(2, firstName: 'Новое'), contact(4)]),
    );

    expect(table.written, unorderedEquals(['c.2', 'c.4']));
    expect(table.deleted, ['c.3']);
  });

  test('another account\'s book is wiped, not merged', () async {
    final store = KeyValueContactsLocalStore(table);
    await store.save(snapshot([contact(1, ownerId: 99)], owner: 99));

    await store.save(snapshot([contact(2)]));

    final restored = KeyValueContactsLocalStore(table).read()!;
    expect(restored.ownerId, kOwnerId);
    expect([for (final c in restored.contacts) c.userId], [2]);
  });

  test('clear forgets everything', () async {
    final store = KeyValueContactsLocalStore(table);
    await store.save(snapshot([contact(1)]));

    await store.clear();

    expect(store.read(), isNull);
    expect(KeyValueContactsLocalStore(table).read(), isNull);
  });

  test('a store from another schema is read as nothing', () async {
    await table.write(
      KeyValueContactsLocalStore.metaKey,
      json.encode({'schema': 0, 'owner_id': kOwnerId}),
    );

    expect(KeyValueContactsLocalStore(table).read(), isNull);
  });

  test('one unreadable row costs that row only', () async {
    await KeyValueContactsLocalStore(
      table,
    ).save(snapshot([contact(1), contact(2)]));
    await table.write('c.2', '{not json');

    final restored = KeyValueContactsLocalStore(table).read()!;

    expect([for (final c in restored.contacts) c.userId], [1]);
  });
}
