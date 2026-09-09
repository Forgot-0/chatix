import 'package:form_builder_validators/form_builder_validators.dart';

class AuthFieldValidators {
  AuthFieldValidators._();

  static String? loginIdentifier(String? value) =>
      FormBuilderValidators.required<String>(
        errorText: 'Enter your email or username',
      )(value);

  static String? username(String? value) =>
      FormBuilderValidators.compose<String>([
        FormBuilderValidators.required(errorText: 'Username is required'),
        FormBuilderValidators.minLength(4, errorText: 'At least 4 characters'),
        FormBuilderValidators.maxLength(
          100,
          errorText: 'At most 100 characters',
        ),
        FormBuilderValidators.match(
          RegExp(r"^[a-zA-Z0-9 ,.'-]+$"),
          errorText: "Only letters, numbers, spaces and , . ' - are allowed",
        ),
      ])(value);

  static String? email(String? value) => FormBuilderValidators.compose<String>([
    FormBuilderValidators.required(errorText: 'Email is required'),
    FormBuilderValidators.email(errorText: 'Enter a valid email address'),
  ])(value);

  static String? password(
    String? value,
  ) => FormBuilderValidators.compose<String>([
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

  static String? Function(String?) passwordRepeat(String Function() password) {
    return FormBuilderValidators.compose<String>([
      FormBuilderValidators.required(errorText: 'Please repeat your password'),
      (value) => value == password() ? null : 'Passwords do not match',
    ]);
  }

  static String? required(String? value) =>
      FormBuilderValidators.required<String>(
        errorText: 'This field is required',
      )(value);
}
