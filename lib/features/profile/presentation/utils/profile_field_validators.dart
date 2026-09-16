import 'package:form_builder_validators/form_builder_validators.dart';

import 'package:chatix/features/profile/domain/usecases/update_profile_use_case.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The profile form's field rules, which are the server's own.
///
/// Checked here so an over-long value costs a form error rather than a round
/// trip and a `TOO_LONG_*` code the form would have to translate back into a
/// field (api-docs §2.5, §4.4). [UpdateProfileUseCase] repeats them, because
/// nothing guarantees every caller came through a form.
class ProfileFieldValidators {
  ProfileFieldValidators._();

  static String? Function(String?) displayName(AppLocalizations l10n) {
    return FormBuilderValidators.maxLength(
      UpdateProfileUseCase.maxDisplayNameLength,
      errorText: l10n.fieldTooLong(UpdateProfileUseCase.maxDisplayNameLength),
    );
  }

  static String? Function(String?) bio(AppLocalizations l10n) {
    return FormBuilderValidators.maxLength(
      UpdateProfileUseCase.maxBioLength,
      errorText: l10n.fieldTooLong(UpdateProfileUseCase.maxBioLength),
    );
  }

  /// Per skill, not for the list: the server's limit is on each element.
  static String? Function(List<String>?) skills(AppLocalizations l10n) {
    return (List<String>? value) {
      for (final skill in value ?? const <String>[]) {
        if (skill.length > UpdateProfileUseCase.maxSkillLength) {
          return l10n.skillTooLong(
            skill,
            UpdateProfileUseCase.maxSkillLength,
          );
        }
      }
      return null;
    };
  }
}
