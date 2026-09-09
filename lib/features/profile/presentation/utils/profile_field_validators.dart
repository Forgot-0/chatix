import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:chatix/features/profile/domain/usecases/update_profile_use_case.dart';

class ProfileFieldValidators {
  ProfileFieldValidators._();

  static String? displayName(String? value) => FormBuilderValidators.maxLength(
    UpdateProfileUseCase.maxDisplayNameLength,
    errorText:
        'At most ${UpdateProfileUseCase.maxDisplayNameLength} characters',
  )(value);

  static String? bio(String? value) => FormBuilderValidators.maxLength(
    UpdateProfileUseCase.maxBioLength,
    errorText: 'At most ${UpdateProfileUseCase.maxBioLength} characters',
  )(value);

  static String? skills(List<String>? value) {
    for (final skill in value ?? const <String>[]) {
      if (skill.length > UpdateProfileUseCase.maxSkillLength) {
        return 'Skill "$skill" exceeds ${UpdateProfileUseCase.maxSkillLength} characters';
      }
    }
    return null;
  }
}
