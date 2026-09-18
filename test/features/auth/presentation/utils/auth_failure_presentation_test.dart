import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  ApiFailure apiFailure(
    String code, {
    dynamic detail = const <String, dynamic>{},
    int status = 400,
  }) => ApiFailure(
    code: code,
    message: 'raw server wording',
    detail: detail,
    status: status,
  );

  group('describeAuthFailure (api-docs §2.4)', () {
    test('WRONG_LOGIN_DATA says so without blaming a field', () {
      final info = describeAuthFailure(
        apiFailure('WRONG_LOGIN_DATA', detail: {'username': 'ada'}),
        l10n,
      );

      expect(info.message, l10n.authErrorWrongLoginData);
      expect(info.field, isNull);
      expect(info.hasAction, isFalse);
    });

    test('EMAIL_NOT_CONFIRMED names the address and offers the resend', () {
      final info = describeAuthFailure(
        apiFailure(
          'EMAIL_NOT_CONFIRMED',
          detail: {'email': 'ada@example.com'},
          status: 403,
        ),
        l10n,
      );

      expect(info.message, contains('ada@example.com'));
      expect(info.action, AuthErrorAction.resendVerification);
      expect(info.email, 'ada@example.com');
    });

    test('EMAIL_NOT_CONFIRMED still offers the resend with no address', () {
      final info = describeAuthFailure(
        apiFailure('EMAIL_NOT_CONFIRMED', status: 403),
        l10n,
      );

      expect(info.message, l10n.authErrorEmailNotConfirmed);
      expect(info.action, AuthErrorAction.resendVerification);
      expect(info.email, isNull);
    });

    test('DUPLICATE_USER points at the field the server blamed', () {
      final username = describeAuthFailure(
        apiFailure(
          'DUPLICATE_USER',
          detail: {'field': 'username', 'value': 'ada'},
          status: 409,
        ),
        l10n,
      );
      expect(username.field, 'username');
      expect(username.message, l10n.authErrorDuplicateUsername);

      final email = describeAuthFailure(
        apiFailure(
          'DUPLICATE_USER',
          detail: {'field': 'email', 'value': 'ada@example.com'},
          status: 409,
        ),
        l10n,
      );
      expect(email.field, 'email');
      expect(email.message, l10n.authErrorDuplicateEmail);
    });

    test('DUPLICATE_USER on an unknown field still names it', () {
      final info = describeAuthFailure(
        apiFailure(
          'DUPLICATE_USER',
          detail: {'field': 'phone', 'value': '+1'},
          status: 409,
        ),
        l10n,
      );

      expect(info.field, 'phone');
      expect(info.message, contains('phone'));
    });

    // 429 never carries an error envelope — the rate limiter answers with a
    // bare {"detail": ...} (api-docs §0.7, §2.2), which the network layer
    // has already turned into RateLimitFailure.
    test('a rate limit gets its own sentence, not the generic one', () {
      final info = describeAuthFailure(
        const RateLimitFailure(message: 'Too Many Requests'),
        l10n,
      );

      expect(info.message, l10n.authErrorTooManyAttempts);
      expect(info.message, isNot(l10n.authErrorGeneric));
    });

    test('a 429 that did come wrapped in an envelope reads the same', () {
      final info = describeAuthFailure(
        apiFailure('SOME_THROTTLE', status: 429),
        l10n,
      );

      expect(info.message, l10n.authErrorTooManyAttempts);
    });

    test('a dead network is not a wrong password', () {
      expect(
        describeAuthFailure(const NetworkFailure(), l10n).message,
        l10n.authErrorOffline,
      );
      expect(
        describeAuthFailure(const TimeoutFailure(), l10n).message,
        l10n.authErrorOffline,
      );
    });

    test('an expired verification code asks for a new one', () {
      for (final code in ['INVALID_TOKEN', 'EXPIRED_TOKEN']) {
        expect(
          describeAuthFailure(apiFailure(code), l10n).message,
          l10n.authErrorInvalidCode,
        );
      }
    });

    test('an unknown code falls back rather than showing nothing', () {
      final info = describeAuthFailure(apiFailure('WHAT_IS_THIS'), l10n);

      expect(info.message, isNotEmpty);
      expect(info.field, isNull);
    });

    test('no error at all is still a sentence', () {
      expect(describeAuthFailure(null, l10n).message, l10n.authErrorGeneric);
    });
  });
}
