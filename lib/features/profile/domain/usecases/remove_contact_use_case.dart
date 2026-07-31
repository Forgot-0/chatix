import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// `DELETE /profiles/{profile_id}/{provider}/delete/` 🔒 (api-docs §4.6).
class RemoveContactUseCase {
  final ProfileRepository _repository;

  RemoveContactUseCase(this._repository);

  Future<Either<Failure, void>> execute(int profileId, {required String provider}) {
    if (profileId <= 0) {
      return Future.value(
        const Left(InputFailure(message: 'profileId must be a positive number')),
      );
    }

    if (provider.isEmpty) {
      return Future.value(const Left(InputFailure(message: 'Provider cannot be empty')));
    }

    return _repository.removeContact(profileId, provider: provider);
  }
}
