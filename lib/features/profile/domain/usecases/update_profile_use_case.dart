import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_update.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// Writes a profile through `PUT /profiles/{id}/`.
///
/// Takes the complete [ProfileUpdate] rather than the fields that changed:
/// the endpoint assigns the body onto the row verbatim, so anything left out
/// of the request is cleared rather than kept (api-docs §4.4).
///
/// The length checks are the same ones the server makes, done here so a
/// too-long value costs a form error instead of a round trip and a
/// `TOO_LONG_*` code (api-docs §2.5).
class UpdateProfileUseCase {
  /// 100 characters or more is `TOO_LONG_DISPLAY_NAME`.
  static const maxDisplayNameLength = 99;

  /// 1024 characters or more is `TOO_LONG_BIO`.
  static const maxBioLength = 1023;

  /// Per skill, not for the list: 31 characters is `TOO_LONG_SKILL_NAME`.
  static const maxSkillLength = 30;

  final ProfileRepository _repository;

  UpdateProfileUseCase(this._repository);

  Future<Either<Failure, void>> execute(int profileId, ProfileUpdate update) {
    if (profileId <= 0) {
      return Future.value(
        const Left(
          InputFailure(message: 'profileId must be a positive number'),
        ),
      );
    }

    final displayName = update.displayName;
    if (displayName != null && displayName.length > maxDisplayNameLength) {
      return Future.value(
        Left(
          InputFailure(
            message:
                'Display name must be $maxDisplayNameLength characters or fewer',
          ),
        ),
      );
    }

    final bio = update.bio;
    if (bio != null && bio.length > maxBioLength) {
      return Future.value(
        Left(
          InputFailure(
            message: 'Bio must be $maxBioLength characters or fewer',
          ),
        ),
      );
    }

    for (final skill in update.skills) {
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

    return _repository.updateProfile(profileId, update);
  }
}
