import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// `POST /profiles/{profile_id}/contacts/` 🔒 (api-docs §4.6).
class AddContactUseCase {
  final ProfileRepository _repository;

  AddContactUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    int profileId, {
    required String provider,
    required String contact,
  }) {
    if (profileId <= 0) {
      return Future.value(
        const Left(InputFailure(message: 'profileId must be a positive number')),
      );
    }

    if (provider.isEmpty || contact.isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Provider and contact cannot be empty')),
      );
    }

    return _repository.addContact(profileId, provider: provider, contact: contact);
  }
}
