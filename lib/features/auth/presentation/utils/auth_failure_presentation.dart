import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The one thing, besides the wording, that an auth error can offer.
enum AuthErrorAction {
  /// `EMAIL_NOT_CONFIRMED`: the account exists and the password was right —
  /// the only thing missing is the letter, so offer to send it again.
  resendVerification,
}

/// An auth failure as the screen should say it.
class AuthErrorInfo {
  const AuthErrorInfo({
    required this.message,
    this.action,
    this.field,
    this.email,
  });

  final String message;

  final AuthErrorAction? action;

  /// The form field the server blamed, where it named one — `DUPLICATE_USER`
  /// carries `{field, value}` (api-docs §2.4), and putting the message on
  /// that field is worth more than a banner above the form.
  final String? field;

  /// The address `EMAIL_NOT_CONFIRMED` named, so the resend does not have to
  /// ask for it again.
  final String? email;

  bool get hasAction => action != null;
}

/// Turns a [Failure] into the sentence and the offer that belong on an auth
/// screen.
///
/// Three things make this different from [friendlyFailureMessage], which it
/// still falls back to:
///
///  * 429 never reaches the error envelope at all — the rate limiter answers
///    with a bare `{"detail": ...}` (api-docs §2.2), which the network layer
///    has already turned into [RateLimitFailure]. It gets its own branch and
///    its own sentence, because "too many attempts" is the only auth error
///    that is not about what was typed.
///  * `EMAIL_NOT_CONFIRMED` is not a dead end: it comes back with an action.
///  * `DUPLICATE_USER` names the field it means, so the error can be put
///    where the reader is looking.
AuthErrorInfo describeAuthFailure(Object? error, AppLocalizations l10n) {
  switch (error) {
    case null:
      return AuthErrorInfo(message: l10n.authErrorGeneric);

    // 429 — `{detail}`, no `error.code` to read (api-docs §0.7).
    case RateLimitFailure():
      return AuthErrorInfo(message: l10n.authErrorTooManyAttempts);

    case NetworkFailure():
    case TimeoutFailure():
      return AuthErrorInfo(message: l10n.authErrorOffline);

    case final ApiFailure failure:
      // Some deployments answer the throttle inside the envelope; the code
      // is unreliable there, the status is not.
      if (failure.status == 429) {
        return AuthErrorInfo(message: l10n.authErrorTooManyAttempts);
      }
      return _describeApiFailure(failure, l10n);

    default:
      return AuthErrorInfo(
        message: friendlyFailureMessage(error, fallback: l10n.authErrorGeneric),
      );
  }
}

AuthErrorInfo _describeApiFailure(ApiFailure failure, AppLocalizations l10n) {
  final detail = failure.detail;
  final fields = detail is Map
      ? Map<String, dynamic>.from(detail)
      : const <String, dynamic>{};

  switch (failure.code) {
    case 'WRONG_LOGIN_DATA':
      return AuthErrorInfo(message: l10n.authErrorWrongLoginData);

    case 'EMAIL_NOT_CONFIRMED':
      final email = fields['email'] as String?;
      return AuthErrorInfo(
        message: email == null || email.isEmpty
            ? l10n.authErrorEmailNotConfirmed
            : l10n.authErrorEmailNotConfirmedFor(email),
        action: AuthErrorAction.resendVerification,
        email: email,
      );

    case 'DUPLICATE_USER':
      final field = fields['field'] as String?;
      return switch (field) {
        'username' => AuthErrorInfo(
          message: l10n.authErrorDuplicateUsername,
          field: 'username',
        ),
        'email' => AuthErrorInfo(
          message: l10n.authErrorDuplicateEmail,
          field: 'email',
        ),
        _ => AuthErrorInfo(
          message: l10n.authErrorDuplicateField(field ?? l10n.username),
          field: field,
        ),
      };

    case 'PASSWORD_MISMATCH':
      return AuthErrorInfo(
        message: l10n.authErrorPasswordMismatch,
        field: 'password_repeat',
      );

    case 'INVALID_TOKEN':
    case 'EXPIRED_TOKEN':
      return AuthErrorInfo(message: l10n.authErrorInvalidCode);

    case 'NOT_FOUND_USER':
      return AuthErrorInfo(message: l10n.authErrorUserNotFound);

    default:
      return AuthErrorInfo(
        message: friendlyFailureMessage(
          failure,
          fallback: l10n.authErrorGeneric,
        ),
      );
  }
}
