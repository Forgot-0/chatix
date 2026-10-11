import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_remote_data_source.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/contacts/domain/repositories/contacts_repository.dart';

/// The cursor stopped moving: the same page would be asked for forever.
class ContactCursorFailure extends Failure {
  const ContactCursorFailure()
    : super(message: 'The contact list cursor did not advance');
}

class ContactsRepositoryImpl implements ContactsRepository {
  ContactsRepositoryImpl({
    required ContactsRemoteDataSource remote,
    required ContactsLocalStore local,
    ContactSyncPolicy policy = ContactSyncPolicy.defaults,
    DateTime Function()? clock,
    this.pageSize = ContactsApi.pageSize,
  }) : _remote = remote,
       _local = local,
       _policy = policy,
       _clock = clock ?? DateTime.now;

  final ContactsRemoteDataSource _remote;
  final ContactsLocalStore _local;
  final ContactSyncPolicy _policy;
  final DateTime Function() _clock;

  final int pageSize;

  /// No book reaches this many pages (5000 contacts, 500 a page); a server
  /// that keeps saying `has_next` past it is not going to stop.
  static const int maxPages = 100;

  /// The sync in progress, shared by everybody who asks for one meanwhile.
  Future<Either<Failure, ContactsSnapshot>>? _syncing;
  int? _syncingOwner;

  /// Contacts written here while a sync was reading pages. The pages may
  /// have been read before the write, so for these the local row — or its
  /// absence — wins over what the sync brought back.
  final Set<int> _touchedDuringSync = <int>{};

  @override
  ContactsSnapshot? cached() => _local.read();

  @override
  Future<Either<Failure, ContactsSnapshot>> sync({
    required int ownerId,
    bool forceFull = false,
  }) async {
    final running = _syncing;
    if (running != null) {
      // The same book is being read already: that answer is this one too.
      if (_syncingOwner == ownerId) return running;
      // Somebody else's — the account changed under it. Let it land, then
      // read this one's from the start.
      await running;
      return sync(ownerId: ownerId, forceFull: forceFull);
    }

    final future = _sync(ownerId: ownerId, forceFull: forceFull);
    _syncing = future;
    _syncingOwner = ownerId;
    try {
      return await future;
    } finally {
      _syncing = null;
      _syncingOwner = null;
      _touchedDuringSync.clear();
    }
  }

  Future<Either<Failure, ContactsSnapshot>> _sync({
    required int ownerId,
    required bool forceFull,
  }) async {
    final stored = _local.read();
    final mine = stored != null && stored.ownerId == ownerId ? stored : null;
    final startedAt = _clock();

    final full =
        forceFull ||
        _policy.needsFullSync(mine, ownerId: ownerId, now: startedAt);

    // A delta starts from what is here and lays the changes over it; a full
    // read starts from nothing, which is the only way a deletion — never
    // sent in a delta — ever reaches this device (api-docs §4.8).
    final rows = <int, Contact>{
      if (!full && mine != null)
        for (final contact in mine.contacts) contact.userId: contact,
    };
    final updatedAfter = full ? null : mine?.version;

    int? cursor;
    String? version;
    for (var pages = 0; ; pages++) {
      if (pages >= maxPages) return const Left(ContactCursorFailure());

      final result = await _remote.fetchPage(
        limit: pageSize,
        afterContactId: cursor,
        updatedAfter: updatedAfter,
      );

      final ContactPage page;
      switch (result) {
        case Left(value: final failure):
          return Left(contactFailureFrom(failure));
        case Right(value: final value):
          page = value;
      }

      // Upsert by contact_id: `updated_after` is compared with `>=`, so the
      // rows on the boundary come again, and a repeat simply lands on itself.
      for (final contact in page.contacts) {
        rows[contact.userId] = contact;
      }

      if (!page.hasNext) {
        // Only the last page carries it (api-docs §0.21).
        version = page.version;
        break;
      }

      final next = page.nextContactId;
      if (next == null || (cursor != null && next <= cursor)) {
        Logger.warning(
          'Contacts sync: cursor stuck at $cursor (next $next), giving up',
        );
        return const Left(ContactCursorFailure());
      }
      cursor = next;
    }

    // Writes that landed while the pages were in flight are newer than the
    // pages: keep them, and keep deleted contacts deleted.
    final current = _local.read();
    if (current != null && current.ownerId == ownerId) {
      final now = {for (final c in current.contacts) c.userId: c};
      for (final id in _touchedDuringSync) {
        final local = now[id];
        if (local == null) {
          rows.remove(id);
        } else {
          rows[id] = local;
        }
      }
    }

    final snapshot = ContactsSnapshot(
      ownerId: ownerId,
      contacts: rows.values.toList(),
      // A last page without a version leaves the next sync a full one,
      // rather than a delta from a mark that does not match these rows.
      version: version ?? (full ? null : mine?.version),
      fullSyncAt: full ? startedAt : mine?.fullSyncAt,
    );
    await _local.save(snapshot);

    Logger.info(
      'Contacts sync: ${full ? 'full' : 'delta'} read, '
      '${snapshot.contacts.length} contacts',
    );
    return Right(snapshot);
  }

  @override
  Future<Either<Failure, Contact>> add({
    int? userId,
    String? username,
    String? firstName,
    String? lastName,
  }) async {
    final result = await _remote.add(
      userId: userId,
      username: username,
      firstName: firstName,
      lastName: lastName,
    );
    return _keep(result);
  }

  @override
  Future<Either<Failure, Contact>> rename(
    int userId, {
    required String? firstName,
    required String? lastName,
  }) async {
    // Both keys, nulls included: a blank half clears that half.
    final result = await _remote.update(userId, {
      'first_name': firstName,
      'last_name': lastName,
    });
    return _keep(result);
  }

  @override
  Future<Either<Failure, Contact>> setFavorite(
    int userId,
    bool isFavorite,
  ) async {
    final result = await _remote.update(userId, {'is_favorite': isFavorite});
    return _keep(result);
  }

  @override
  Future<Either<Failure, void>> remove(int userId) async {
    final result = await _remote.delete(userId);

    switch (result) {
      case Left(value: final failure):
        final mapped = contactFailureFrom(failure);
        // Gone already — from another device, say. The book should agree.
        if (mapped is ContactNotFoundFailure) await _drop(userId);
        return Left(mapped);
      case Right():
        await _drop(userId);
        return const Right(null);
    }
  }

  @override
  Future<Either<Failure, List<ContactSearchHit>>> search(
    String query, {
    int limit = ContactsApi.searchLimit,
    RequestCancellation? cancellation,
  }) async {
    final result = await _remote.search(
      query,
      limit: limit,
      cancellation: cancellation,
    );
    return result.mapLeft(contactFailureFrom);
  }

  @override
  Future<Either<Failure, ContactImportResult>> importBatch(
    List<ContactImportEntry> entries, {
    required String idempotencyKey,
  }) async {
    final result = await _remote.importContacts(
      entries,
      idempotencyKey: idempotencyKey,
    );

    switch (result) {
      case Left(value: final failure):
        return Left(contactFailureFrom(failure));
      case Right(value: final imported):
        if (imported.contacts.isNotEmpty) await _upsert(imported.contacts);
        return Right(imported);
    }
  }

  Future<Either<Failure, Contact>> _keep(
    Either<Failure, Contact> result,
  ) async {
    switch (result) {
      case Left(value: final failure):
        return Left(contactFailureFrom(failure));
      case Right(value: final contact):
        await _upsert([contact]);
        return Right(contact);
    }
  }

  Future<void> _upsert(List<Contact> contacts) async {
    final ownerId = contacts.first.ownerId;
    final stored = _local.read();
    final base = stored != null && stored.ownerId == ownerId ? stored : null;

    final rows = {
      for (final contact in base?.contacts ?? const <Contact>[])
        contact.userId: contact,
      for (final contact in contacts) contact.userId: contact,
    };

    _touch(contacts.map((c) => c.userId));
    await _local.save(
      base?.copyWith(contacts: rows.values.toList()) ??
          ContactsSnapshot(ownerId: ownerId, contacts: rows.values.toList()),
    );
  }

  /// Only while a sync is reading: a write before it started is already in
  /// what it reads.
  void _touch(Iterable<int> userIds) {
    if (_syncing != null) _touchedDuringSync.addAll(userIds);
  }

  Future<void> _drop(int userId) async {
    final stored = _local.read();
    if (stored == null) return;

    _touch([userId]);
    await _local.save(
      stored.copyWith(
        contacts: [
          for (final contact in stored.contacts)
            if (contact.userId != userId) contact,
        ],
      ),
    );
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepositoryImpl(
    remote: ref.watch(contactsRemoteDataSourceProvider),
    local: ref.watch(contactsLocalStoreProvider),
  ),
);
