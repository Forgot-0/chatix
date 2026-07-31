import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// `PUT /profiles/{profile_id}/` 🔒 (api-docs §4.4).
///
/// ⚠️ Not a partial update in practice: the backend applies whatever
/// fields it receives, including explicit `null`s (api-docs §4.4). Callers
/// (`ProfileEditScreen`) must pass the full current value for every field,
/// not just the one the person actually changed, or unrelated fields will
/// get wiped to `null`.
class UpdateProfileUseCase {
  // api-docs §4.4 request schema. (§2.5's error-code table separately says
  // "1024 симв" for bio; §4.4's own request-schema comment is more
  // specific at "≤ 1023" — using the stricter 1023 here so a client-side
  // check never lets through something the server would reject.)
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
