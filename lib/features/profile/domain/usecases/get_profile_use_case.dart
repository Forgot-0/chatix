import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// `GET /profiles/{profile_id}/` 🔓 (api-docs §4.3).
class GetProfileUseCase {
  final ProfileRepository _repository;

  GetProfileUseCase(this._repository);

  Future<Either<Failure, ProfileEntity>> execute(int profileId) {
    if (profileId <= 0) {
      return Future.value(
        const Left(InputFailure(message: 'profileId must be a positive number')),
      );
    }

    return _repository.getProfile(profileId);
  }
}
