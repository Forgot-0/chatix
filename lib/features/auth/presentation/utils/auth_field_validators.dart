import 'package:form_builder_validators/form_builder_validators.dart';

import 'package:chatix/gen/l10n/app_localizations.dart';

/// The sign-in, registration and password-reset field rules.
///
/// Each takes the reader's [AppLocalizations] and hands back the validator,
/// the way `ProfileFieldValidators` does: a rule is the same in every
/// language, the sentence it fails with is not.
class AuthFieldValidators {
  AuthFieldValidators._();

  static const int usernameMinLength = 4;
  static const int usernameMaxLength = 100;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 128;

  /// What counts as a special character. Shown to the reader as-is, so it
  /// is passed into the sentence rather than written into every translation.
  static const String passwordSpecialCharacters = r'!@#$%^&*(),.?":{}|<>';

  static String? Function(String?) loginIdentifier(AppLocalizations l10n) =>
      FormBuilderValidators.required<String>(
        errorText: l10n.validationLoginIdentifierRequired,
      );

  static String? Function(String?) username(AppLocalizations l10n) =>
      FormBuilderValidators.compose<String>([
        FormBuilderValidators.required(
          errorText: l10n.validationUsernameRequired,
        ),
        FormBuilderValidators.minLength(
          usernameMinLength,
          errorText: l10n.validationMinLength(usernameMinLength),
        ),
        FormBuilderValidators.maxLength(
          usernameMaxLength,
          errorText: l10n.fieldTooLong(usernameMaxLength),
        ),
        FormBuilderValidators.match(
          RegExp(r"^[a-zA-Z0-9 ,.'-]+$"),
          errorText: l10n.validationUsernameCharacters,
        ),
      ]);

  static String? Function(String?) email(AppLocalizations l10n) =>
      FormBuilderValidators.compose<String>([
        FormBuilderValidators.required(errorText: l10n.validationEmailRequired),
        FormBuilderValidators.email(errorText: l10n.validationEmailInvalid),
      ]);

  static String? Function(String?) password(AppLocalizations l10n) =>
      FormBuilderValidators.compose<String>([
        FormBuilderValidators.required(
          errorText: l10n.validationPasswordRequired,
        ),
        FormBuilderValidators.minLength(
          passwordMinLength,
          errorText: l10n.validationMinLength(passwordMinLength),
        ),
        FormBuilderValidators.maxLength(
          passwordMaxLength,
          errorText: l10n.fieldTooLong(passwordMaxLength),
        ),
        FormBuilderValidators.hasUppercaseChars(
          errorText: l10n.validationPasswordUppercase,
        ),
        FormBuilderValidators.hasLowercaseChars(
          errorText: l10n.validationPasswordLowercase,
        ),
        FormBuilderValidators.hasNumericChars(
          errorText: l10n.validationPasswordDigit,
        ),
        FormBuilderValidators.hasSpecialChars(
          regex: RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
          errorText: l10n.validationPasswordSpecial(passwordSpecialCharacters),
        ),
      ]);

  static String? Function(String?) passwordRepeat(
    AppLocalizations l10n,
    String Function() password,
  ) {
    return FormBuilderValidators.compose<String>([
      FormBuilderValidators.required(
        errorText: l10n.validationPasswordRepeatRequired,
      ),
      (value) =>
          value == password() ? null : l10n.validationPasswordsDoNotMatch,
    ]);
  }

  static String? Function(String?) required(AppLocalizations l10n) =>
      FormBuilderValidators.required<String>(
        errorText: l10n.validationFieldRequired,
      );
}
