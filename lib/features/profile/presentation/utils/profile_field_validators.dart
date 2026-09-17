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

  static String? Function(String?) _maxLengthAllowEmpty(
    int maxLength,
    AppLocalizations l10n,
  ) {
    return (String? value) {
      if (value == null) return null;

      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.length > maxLength) {
        return l10n.fieldTooLong(maxLength);
      }
      return null;
    };
  }

  static String? Function(String?) displayName(AppLocalizations l10n) {
    return _maxLengthAllowEmpty(
      UpdateProfileUseCase.maxDisplayNameLength,
      l10n,
    );
  }

  static String? Function(String?) bio(AppLocalizations l10n) {
    return _maxLengthAllowEmpty(UpdateProfileUseCase.maxBioLength, l10n);
  }

  /// Per skill, not for the list: the server's limit is on each element.
  static String? Function(List<String>?) skills(AppLocalizations l10n) {
    return (List<String>? value) {
      for (final skill in value ?? const <String>[]) {
        if (skill.length > UpdateProfileUseCase.maxSkillLength) {
          return l10n.skillTooLong(skill, UpdateProfileUseCase.maxSkillLength);
        }
      }
      return null;
    };
  }
}
