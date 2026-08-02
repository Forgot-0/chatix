import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// `GET /profiles/my/` 🔓 (api-docs §4.3).
class GetMyProfileUseCase {
  final ProfileRepository _repository;

  GetMyProfileUseCase(this._repository);

  Future<Either<Failure, ProfileEntity>> execute() {
    return _repository.getMyProfile();
  }
}
