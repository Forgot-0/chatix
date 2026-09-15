import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// Reads the signed-in user's profile through `GET /profiles/my/`, which
/// creates the row when it is missing (api-docs §4.1).
///
/// A profile is normally written by the `profiles` consumer reacting to
/// `auth.user.verified`, and that travels outbox → Debezium → Kafka, so right
/// after a first sign-in it may not exist yet. Calling this once per login is
/// cheaper than letting every profile screen discover the gap as a 404 —
/// `GET /profiles/{id}/` has no create-if-missing behaviour.
class EnsureMyProfileUseCase {
  final ProfileRepository _repository;

  EnsureMyProfileUseCase(this._repository);

  Future<Either<Failure, ProfileEntity>> execute() {
    return _repository.getMyProfile();
  }
}
