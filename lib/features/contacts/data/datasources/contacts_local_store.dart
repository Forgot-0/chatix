import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/contacts/data/models/contact_models.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';

/// This device's copy of the address book: what makes the contacts tab open
/// on a frame instead of a request, and what puts local names on the chat
/// list before any network has answered.
abstract interface class ContactsLocalStore {
  /// The stored book, or null when there is none. Synchronous: it is read
  /// while the first frame is being built.
  ContactsSnapshot? read();

  /// Makes the store hold exactly [snapshot].
  Future<void> save(ContactsSnapshot snapshot);

  Future<void> clear();
}

/// The store over one key-value table: a `meta` row for whose book it is
/// and how fresh, and one row per contact in the API's own JSON.
///
/// One row per contact rather than one blob, so a delta of three changed
/// contacts writes three rows, not five thousand. [save] works that out
/// itself by comparing with what it last wrote.
class KeyValueContactsLocalStore implements ContactsLocalStore {
  KeyValueContactsLocalStore(this._table);

  static const String metaKey = 'meta';
  static const String contactPrefix = 'c.';

  /// Bumped when the row format changes; a store written by another version
  /// is dropped and read again from the server.
  static const int schema = 1;

  final LocalKeyValueTable _table;

  /// What the table holds, decoded once: [save] diffs against it.
  ContactsSnapshot? _mirror;
  bool _loaded = false;

  @override
  ContactsSnapshot? read() {
    if (!_loaded) {
      _mirror = _decode();
      _loaded = true;
    }
    return _mirror;
  }

  ContactsSnapshot? _decode() {
    final rawMeta = _table.read(metaKey);
    if (rawMeta == null) return null;

    try {
      final meta = (json.decode(rawMeta) as Map).cast<String, dynamic>();
      if (meta['schema'] != schema) return null;

      final contacts = <Contact>[];
      for (final key in _table.keys()) {
        if (!key.startsWith(contactPrefix)) continue;
        final raw = _table.read(key);
        if (raw == null) continue;
        try {
          contacts.add(ContactJson.contact((json.decode(raw) as Map).cast()));
        } catch (error) {
          // One unreadable row costs that row until the next full read.
          Logger.warning('Contacts cache: skipping row $key ($error)');
        }
      }

      final fullSyncAt = meta['full_sync_at'];
      return ContactsSnapshot(
        ownerId: meta['owner_id'] as int,
        contacts: contacts,
        version: meta['version'] as String?,
        fullSyncAt: fullSyncAt is String ? DateTime.tryParse(fullSyncAt) : null,
      );
    } catch (error) {
      Logger.warning('Contacts cache: unreadable, starting over ($error)');
      return null;
    }
  }

  @override
  Future<void> save(ContactsSnapshot snapshot) async {
    final previous = read();
    final before = <int, Contact>{
      if (previous != null && previous.ownerId == snapshot.ownerId)
        for (final contact in previous.contacts) contact.userId: contact,
    };
    final after = <int, Contact>{
      for (final contact in snapshot.contacts) contact.userId: contact,
    };

    // Somebody else's book, or none: every row goes.
    if (previous != null && previous.ownerId != snapshot.ownerId) {
      await _table.clear();
    }

    final gone = [
      for (final id in before.keys)
        if (!after.containsKey(id)) '$contactPrefix$id',
    ];
    final changed = <String, String>{
      for (final entry in after.entries)
        if (before[entry.key] != entry.value)
          '$contactPrefix${entry.key}': json.encode(
            ContactJson.contactToJson(entry.value),
          ),
    };

    if (gone.isNotEmpty) await _table.deleteAll(gone);
    if (changed.isNotEmpty) await _table.writeAll(changed);
    await _table.write(
      metaKey,
      json.encode({
        'schema': schema,
        'owner_id': snapshot.ownerId,
        'version': snapshot.version,
        'full_sync_at': snapshot.fullSyncAt?.toUtc().toIso8601String(),
      }),
    );

    _mirror = snapshot;
    _loaded = true;
  }

  @override
  Future<void> clear() async {
    await _table.clear();
    _mirror = null;
    _loaded = true;
  }
}

/// The Hive box the book is kept in, versioned like the chat cache's.
abstract final class ContactsBoxes {
  static const String book = 'contacts.v1.book';
}

/// Opens the on-disk store, or an in-memory one if the disk will not open —
/// in which case the book is simply read from the server every launch.
Future<ContactsLocalStore> openHiveContactsLocalStore() async {
  try {
    final box = await openRecoverableHiveBox(
      ContactsBoxes.book,
      label: 'Contacts cache',
    );
    return KeyValueContactsLocalStore(HiveKeyValueTable(box));
  } catch (error, stackTrace) {
    Logger.error(
      'Contacts cache: could not be opened, running without one',
      error,
      stackTrace,
    );
    return KeyValueContactsLocalStore(MemoryKeyValueTable());
  }
}

/// The store this build talks to: memory by default — tests, and any setup
/// that never opened Hive — and the Hive box, overridden in `main()`.
final contactsLocalStoreProvider = Provider<ContactsLocalStore>(
  (ref) => KeyValueContactsLocalStore(MemoryKeyValueTable()),
);
