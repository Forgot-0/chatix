import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';

/// The address book (`/contacts`, api-docs §4.7–4.13), with a copy on this
/// device that every write keeps up to date.
///
/// Failures that the book has a name for come back as `ContactFailure`s.
abstract interface class ContactsRepository {
  /// What this device holds right now, without asking anybody. Null when
  /// nothing has been stored yet.
  ContactsSnapshot? cached();

  /// Brings the copy up to date: a delta from the last `version` when there
  /// is one, the whole list otherwise or when [forceFull] (api-docs §4.8).
  Future<Either<Failure, ContactsSnapshot>> sync({
    required int ownerId,
    bool forceFull = false,
  });

  /// `POST /contacts/` by exactly one of [userId] and [username].
  Future<Either<Failure, Contact>> add({
    int? userId,
    String? username,
    String? firstName,
    String? lastName,
  });

  /// Sets the local name; nulls clear it.
  Future<Either<Failure, Contact>> rename(
    int userId, {
    required String? firstName,
    required String? lastName,
  });

  Future<Either<Failure, Contact>> setFavorite(int userId, bool isFavorite);

  Future<Either<Failure, void>> remove(int userId);

  Future<Either<Failure, List<ContactSearchHit>>> search(
    String query, {
    int limit = 50,
    RequestCancellation? cancellation,
  });

  /// One `POST /contacts/import/` of at most `ContactImportLimits.maxBatch`.
  Future<Either<Failure, ContactImportResult>> importBatch(
    List<ContactImportEntry> entries, {
    required String idempotencyKey,
  });
}
