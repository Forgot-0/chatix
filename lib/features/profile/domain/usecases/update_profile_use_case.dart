import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfileUseCase {
  static const maxDisplayNameLength = 99;
  static const maxBioLength = 1023;
  static const maxSkillLength = 30;

  final ProfileRepository _repository;

  UpdateProfileUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    int profileId, {
    String? specialization,
    String? displayName,
    String? bio,
    List<String>? skills,
    DateTime? dateBirthday,
  }) {
    if (profileId <= 0) {
      return Future.value(
        const Left(InputFailure(message: 'profileId must be a positive number')),
      );
    }

    if (displayName != null && displayName.length > maxDisplayNameLength) {
      return Future.value(
        Left(
          InputFailure(
            message: 'Display name must be $maxDisplayNameLength characters or fewer',
          ),
        ),
      );
    }

    if (bio != null && bio.length > maxBioLength) {
      return Future.value(
        Left(InputFailure(message: 'Bio must be $maxBioLength characters or fewer')),
      );
    }

    if (skills != null) {
      for (final skill in skills) {
        if (skill.length > maxSkillLength) {
          return Future.value(
            Left(
              InputFailure(
                message: 'Skill "$skill" exceeds $maxSkillLength characters',
              ),
            ),
          );
        }
      }
    }

    return _repository.updateProfile(
      profileId,
      specialization: specialization,
      displayName: displayName,
      bio: bio,
      skills: skills,
      dateBirthday: dateBirthday,
    );
  }
}
