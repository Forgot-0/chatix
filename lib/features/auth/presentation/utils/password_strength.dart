import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';

/// How far a password is from what the server will accept.
///
/// The bar is the API's own rule, not a guess: `POST /users/register/`
/// rejects anything under 8 characters or missing an uppercase letter, a
/// lowercase letter, a digit or one of `!@#$%^&*(),.?":{}|<>` — and it
/// rejects it at the schema level, with a bare `422 VALIDATION` that names
/// nothing (api-docs §3.2). Saying so before the request is sent is the only
/// way anyone finds out which rule they missed.
enum PasswordStrength {
  /// Nothing typed yet.
  empty,

  /// Would be refused by the server as it stands.
  weak,

  /// Meets every rule, with nothing to spare.
  fair,

  /// Meets every rule and is comfortably long.
  good,

  /// Long and varied.
  strong;

  /// Whether the server's own rules are all satisfied.
  bool get isAcceptable => index >= PasswordStrength.fair.index;

  /// 0…1, for drawing a meter. `empty` is not zero-width by accident: the
  /// track is drawn empty and the bar grows out of it.
  double get fraction => switch (this) {
    PasswordStrength.empty => 0,
    PasswordStrength.weak => 0.25,
    PasswordStrength.fair => 0.5,
    PasswordStrength.good => 0.75,
    PasswordStrength.strong => 1,
  };
}

/// The single special-character class the backend accepts (api-docs §3.2).
final RegExp _special = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
final RegExp _upper = RegExp('[A-Z]');
final RegExp _lower = RegExp('[a-z]');
final RegExp _digit = RegExp('[0-9]');

/// One of the rules `POST /users/register/` and the password reset hold a
/// new password to (api-docs §3.2, §3.7), in the order the forms list them.
///
/// The server checks them all at once and answers a miss with a bare
/// `422 VALIDATION`, so the forms tick them off one by one as the password
/// is typed instead.
enum PasswordRule {
  /// 8 to 128 characters.
  length,
  uppercase,
  lowercase,
  digit,

  /// One of `!@#$%^&*(),.?":{}|<>` — and only those: `-` or `_` do not count.
  special;

  bool isMetBy(String password) => switch (this) {
    PasswordRule.length =>
      password.length >= AuthFieldValidators.passwordMinLength &&
          password.length <= AuthFieldValidators.passwordMaxLength,
    PasswordRule.uppercase => _upper.hasMatch(password),
    PasswordRule.lowercase => _lower.hasMatch(password),
    PasswordRule.digit => _digit.hasMatch(password),
    PasswordRule.special => _special.hasMatch(password),
  };
}

/// Scores [password] the way the server would, then keeps going.
///
/// Anything the server would refuse is [PasswordStrength.weak], however long
/// it is — a 40-character passphrase with no digit in it is not "strong"
/// here, because registration will bounce it. Above that line, length and
/// variety are what separate the three passing grades.
PasswordStrength estimatePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;

  final acceptable = PasswordRule.values.every(
    (rule) => rule.isMetBy(password),
  );
  if (!acceptable) return PasswordStrength.weak;

  if (password.length >= 16) return PasswordStrength.strong;
  if (password.length >= 12) return PasswordStrength.good;
  return PasswordStrength.fair;
}
