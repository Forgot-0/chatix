import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/contacts/domain/repositories/contacts_repository.dart';

class SyncContactsUseCase {
  const SyncContactsUseCase(this._repository);

  final ContactsRepository _repository;

  Future<Either<Failure, ContactsSnapshot>> execute({
    required int ownerId,
    bool forceFull = false,
  }) => _repository.sync(ownerId: ownerId, forceFull: forceFull);
}

/// `POST /contacts/` — by user id from a profile, or by `@username`.
class SaveContactUseCase {
  const SaveContactUseCase(this._repository);

  final ContactsRepository _repository;

  Future<Either<Failure, Contact>> execute({
    int? userId,
    String? username,
    String? firstName,
    String? lastName,
  }) {
    final handle = username == null
        ? null
        : ContactSearchQuery.stripAt(username);

    // Exactly one target, or the server answers 422 (api-docs §4.9).
    if ((userId == null) == (handle == null || handle.isEmpty)) {
      return Future.value(
        const Left(
          InputFailure(message: 'Pass either a user id or a username'),
        ),
      );
    }

    return _checkNames(firstName, lastName).match(
      (failure) async => Left(failure),
      (names) => _repository.add(
        userId: userId,
        username: userId == null ? handle : null,
        firstName: names.$1,
        lastName: names.$2,
      ),
    );
  }
}

/// `PATCH /contacts/{user_id}/` — the owner's private marks on a contact.
class EditContactUseCase {
  const EditContactUseCase(this._repository);

  final ContactsRepository _repository;

  /// Blank names clear the local name, so the person's own shows again.
  Future<Either<Failure, Contact>> rename(
    int userId, {
    String? firstName,
    String? lastName,
  }) {
    return _checkNames(firstName, lastName).match(
      (failure) async => Left(failure),
      (names) =>
          _repository.rename(userId, firstName: names.$1, lastName: names.$2),
    );
  }

  Future<Either<Failure, Contact>> setFavorite(int userId, bool isFavorite) =>
      _repository.setFavorite(userId, isFavorite);
}

class DeleteContactUseCase {
  const DeleteContactUseCase(this._repository);

  final ContactsRepository _repository;

  Future<Either<Failure, void>> execute(int userId) =>
      _repository.remove(userId);
}

/// `GET /contacts/search/` — and only when the server would search at all,
/// so a one-letter prefix costs no request (api-docs §4.12).
class SearchContactsUseCase {
  const SearchContactsUseCase(this._repository);

  final ContactsRepository _repository;

  Future<Either<Failure, List<ContactSearchHit>>> execute(
    String query, {
    RequestCancellation? cancellation,
  }) async {
    final trimmed = query.trim();
    if (!ContactSearchQuery.isSearchable(trimmed)) {
      return const Right(<ContactSearchHit>[]);
    }

    // `@name` is exact on the server; a space typed after it would never
    // match, so it is not sent.
    final sent = ContactSearchQuery.isUsername(trimmed)
        ? '@${ContactSearchQuery.stripAt(trimmed)}'
        : trimmed;

    return _repository.search(sent, cancellation: cancellation);
  }
}

/// Trimmed names, blanks as null, each within `Contact.maxNameLength`.
Either<Failure, (String?, String?)> _checkNames(String? first, String? last) {
  String? clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  final a = clean(first);
  final b = clean(last);
  for (final name in [a, b]) {
    if (name != null && name.length > Contact.maxNameLength) {
      return const Left(ContactNameTooLongFailure());
    }
  }
  return Right((a, b));
}
