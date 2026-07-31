import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:chatix/features/profile/domain/usecases/update_profile_use_case.dart';

/// Client-side mirrors of the backend's validation rules (api-docs §4.4,
/// §2.5) so the person gets instant feedback instead of a wasted round trip
/// to `TOO_LONG_DISPLAY_NAME`/`TOO_LONG_BIO`/`TOO_LONG_SKILL_NAME`. Reuses
/// `UpdateProfileUseCase`'s limit constants so the two never drift apart.
class ProfileFieldValidators {
  ProfileFieldValidators._();

  static String? displayName(String? value) => FormBuilderValidators.maxLength(
    UpdateProfileUseCase.maxDisplayNameLength,
    errorText: 'At most ${UpdateProfileUseCase.maxDisplayNameLength} characters',
  )(value);

  static String? bio(String? value) => FormBuilderValidators.maxLength(
    UpdateProfileUseCase.maxBioLength,
    errorText: 'At most ${UpdateProfileUseCase.maxBioLength} characters',
  )(value);

  /// Validates every chip in the skills list, not just a single field.
  static String? skills(List<String>? value) {
    for (final skill in value ?? const <String>[]) {
      if (skill.length > UpdateProfileUseCase.maxSkillLength) {
        return 'Skill "$skill" exceeds ${UpdateProfileUseCase.maxSkillLength} characters';
      }
    }
    return null;
  }
}
