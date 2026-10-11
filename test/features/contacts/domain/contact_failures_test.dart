import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';

/// `body.error.code` and `body.error.detail` of the profiles module
/// (api-docs §2.5) become failures the screens can name.
void main() {
  ApiFailure api(String code, int status, [Object? detail]) => ApiFailure(
    code: code,
    message: 'English for a log',
    detail: detail ?? const <String, dynamic>{},
    status: status,
  );

  test('SELF_CONTACT_NOT_ALLOWED', () {
    expect(
      contactFailureFrom(api('SELF_CONTACT_NOT_ALLOWED', 400)),
      const SelfContactFailure(),
    );
  });

  test('CONTACT_BLOCKED carries the user id', () {
    expect(
      contactFailureFrom(api('CONTACT_BLOCKED', 409, {'user_id': 42})),
      const ContactBlockedFailure(userId: 42),
    );
  });

  test('CONTACT_LIMIT_EXCEEDED carries the limit, 5000 when it does not', () {
    expect(
      contactFailureFrom(api('CONTACT_LIMIT_EXCEEDED', 409, {'limit': 300})),
      const ContactLimitFailure(limit: 300),
    );
    expect(
      contactFailureFrom(api('CONTACT_LIMIT_EXCEEDED', 409, null)),
      const ContactLimitFailure(limit: 5000),
    );
  });

  test(
    'NOT_FOUND_CONTACT_TARGET carries whichever of id/username was sent',
    () {
      expect(
        contactFailureFrom(
          api('NOT_FOUND_CONTACT_TARGET', 404, {
            'user_id': null,
            'username': 'ghost',
          }),
        ),
        const ContactTargetNotFoundFailure(username: 'ghost'),
      );
      expect(
        contactFailureFrom(
          api('NOT_FOUND_CONTACT_TARGET', 404, {
            'user_id': 9,
            'username': null,
          }),
        ),
        const ContactTargetNotFoundFailure(userId: 9),
      );
    },
  );

  test('NOT_FOUND_CONTACT, TOO_LONG_CONTACT_NAME', () {
    expect(
      contactFailureFrom(api('NOT_FOUND_CONTACT', 404, {'contact_id': 5})),
      const ContactNotFoundFailure(contactId: 5),
    );
    expect(
      contactFailureFrom(api('TOO_LONG_CONTACT_NAME', 400, {'name': 'x'})),
      const ContactNameTooLongFailure(),
    );
  });

  test('the import codes', () {
    expect(
      contactFailureFrom(
        api('IMPORT_BATCH_TOO_LARGE', 400, {'limit': 500, 'current': 501}),
      ),
      const ImportBatchTooLargeFailure(limit: 500, current: 501),
    );
    expect(
      contactFailureFrom(
        api('IDENTIFIER_QUOTA_EXCEEDED', 429, {'limit': 5000, 'period': '24h'}),
      ),
      const IdentifierQuotaFailure(limit: 5000),
    );
    expect(
      contactFailureFrom(api('IDEMPOTENCY_CONFLICT', 409)),
      const ImportInProgressFailure(),
    );
    expect(
      contactFailureFrom(api('IDENTIFIER_PEPPER_NOT_CONFIGURED', 503)),
      const ImportUnavailableFailure(),
    );
  });

  test('numbers sent as strings or floats still read', () {
    expect(
      contactFailureFrom(api('CONTACT_LIMIT_EXCEEDED', 409, {'limit': '10'})),
      const ContactLimitFailure(limit: 10),
    );
    expect(
      contactFailureFrom(api('CONTACT_BLOCKED', 409, {'user_id': 42.0})),
      const ContactBlockedFailure(userId: 42),
    );
  });

  test('anything else passes through untouched', () {
    final validation = api('VALIDATION', 422, [
      {
        'loc': ['body', 'user_id'],
        'msg': 'field required',
      },
    ]);
    expect(contactFailureFrom(validation), same(validation));

    // The rate limiter's bare `{"detail": ...}` 429 is not the quota one.
    const limited = RateLimitFailure();
    expect(contactFailureFrom(limited), same(limited));

    const offline = NetworkFailure();
    expect(contactFailureFrom(offline), same(offline));
  });
}
