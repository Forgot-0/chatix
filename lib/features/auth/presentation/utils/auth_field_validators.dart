import 'package:form_builder_validators/form_builder_validators.dart';

/// Client-side mirrors of the backend's validation rules (api-docs §3.2,
/// §3.3) so the person gets instant feedback in the form instead of a
/// wasted round trip to `422 VALIDATION` / `400 PASSWORD_MISMATCH`. The
/// backend remains the source of truth for these rules — this is a UX
/// nicety, not a security boundary.
class AuthFieldValidators {
  AuthFieldValidators._();

  /// The login field accepts either an email or a username in the same
  /// text field (api-docs §3.3) — so it only gets a "required" check, no
  /// format constraint.
  static String? loginIdentifier(String? value) =>
      FormBuilderValidators.required<String>(
        errorText: 'Enter your email or username',
      )(value);

  /// api-docs §3.2: 4–100 chars, `^[a-zA-Z0-9 ,.'-]+$`.
  static String? username(String? value) => FormBuilderValidators.compose<String>([
    FormBuilderValidators.required(errorText: 'Username is required'),
    FormBuilderValidators.minLength(4, errorText: 'At least 4 characters'),
    FormBuilderValidators.maxLength(100, errorText: 'At most 100 characters'),
    FormBuilderValidators.match(
      RegExp(r"^[a-zA-Z0-9 ,.'-]+$"),
      errorText: "Only letters, numbers, spaces and , . ' - are allowed",
    ),
  ])(value);

  static String? email(String? value) => FormBuilderValidators.compose<String>([
    FormBuilderValidators.required(errorText: 'Email is required'),
    FormBuilderValidators.email(errorText: 'Enter a valid email address'),
  ])(value);

  /// api-docs §3.2: 8–128 chars, needs upper + lower + digit + one of
  /// `!@#$%^&*(),.?":{}|<>`.
  static String? password(String? value) => FormBuilderValidators.compose<String>([
    FormBuilderValidators.required(errorText: 'Password is required'),
    FormBuilderValidators.minLength(8, errorText: 'At least 8 characters'),
    FormBuilderValidators.maxLength(128, errorText: 'At most 128 characters'),
    FormBuilderValidators.hasUppercaseChars(
      errorText: 'Add at least one uppercase letter',
    ),
    FormBuilderValidators.hasLowercaseChars(
      errorText: 'Add at least one lowercase letter',
    ),
    FormBuilderValidators.hasNumericChars(errorText: 'Add at least one digit'),
    FormBuilderValidators.hasSpecialChars(
      regex: RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
      errorText: 'Add at least one special character (!@#\$%^&*(),.?":{}|<>)',
    ),
  ])(value);

  /// Validates a "repeat password" field against the primary password
  /// field's *current* text. [password] is a getter (not a snapshot) so it
  /// always reads the latest value at validation time.
  static String? Function(String?) passwordRepeat(String Function() password) {
    return FormBuilderValidators.compose<String>([
      FormBuilderValidators.required(errorText: 'Please repeat your password'),
      (value) => value == password() ? null : 'Passwords do not match',
    ]);
  }

  static String? required(String? value) => FormBuilderValidators.required<String>(
    errorText: 'This field is required',
  )(value);
}
