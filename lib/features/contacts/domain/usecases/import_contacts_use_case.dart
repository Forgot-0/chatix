import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/repositories/contacts_repository.dart';

/// `POST /contacts/import/`, in as many requests as the list needs.
///
/// Up to `ContactImportLimits.syncBatch` entries go in one request and come
/// back matched; a longer list is cut into batches of at most
/// `ContactImportLimits.maxBatch`, each of which the server queues and
/// reports on over the socket (api-docs §4.11, §4.13).
///
/// Every batch carries an `Idempotency-Key` from [keyFor]. The caller hands
/// out the same key for the same batch until it succeeds, so a retry after a
/// lost answer is recognised by the server instead of imported twice.
class ImportContactsUseCase {
  const ImportContactsUseCase(this._repository);

  final ContactsRepository _repository;

  Future<Either<Failure, ContactImportResult>> execute(
    List<ContactImportEntry> entries, {
    required String Function(List<ContactImportEntry> batch) keyFor,
  }) async {
    if (entries.isEmpty) {
      return const Left(InputFailure(message: 'Nothing to import'));
    }

    ContactImportResult? total;
    for (
      var start = 0;
      start < entries.length;
      start += ContactImportLimits.maxBatch
    ) {
      final end = start + ContactImportLimits.maxBatch < entries.length
          ? start + ContactImportLimits.maxBatch
          : entries.length;
      final batch = entries.sublist(start, end);

      final result = await _repository.importBatch(
        batch,
        idempotencyKey: keyFor(batch),
      );
      switch (result) {
        // Batches already sent stay imported; a retry sends them again
        // under the same keys and the server answers from its record.
        case Left():
          return result;
        case Right(value: final done):
          total = total == null ? done : mergeImportResults(total, done);
      }
    }
    return Right(total!);
  }
}
