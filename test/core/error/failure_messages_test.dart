import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';

ApiFailure _api(String code, {String message = 'server-facing text'}) =>
    ApiFailure(code: code, message: message, detail: null, status: 400);

void main() {
  group('the codes the UI shows most often', () {
    test('WRONG_LOGIN_DATA', () {
      expect(
        friendlyFailureMessage(_api('WRONG_LOGIN_DATA')),
        'Incorrect username or password.',
      );
    });

    test('ACCESS_DENIED', () {
      expect(
        friendlyFailureMessage(_api('ACCESS_DENIED')),
        "You don't have permission to do that.",
      );
    });

    test('MESSAGE_TOO_LONG', () {
      expect(
        friendlyFailureMessage(_api('MESSAGE_TOO_LONG')),
        'That message is too long. Please shorten it.',
      );
    });
  });

  group('prefix/suffix families', () {
    test('every NOT_FOUND_* variant gets one honest sentence', () {
      for (final code in [
        'NOT_FOUND_PROFILE',
        'NOT_FOUND_CHAT',
        'NOT_FOUND_MESSAGE',
        'NOT_FOUND_SOMETHING_INVENTED_LATER',
      ]) {
        expect(
          friendlyFailureMessage(_api(code)),
          "We couldn't find that — it may have been deleted.",
          reason: code,
        );
      }
    });

    test('module-specific *_ACCESS_DENIED codes are covered too', () {
      for (final code in [
        'CHAT_ACCESS_DENIED',
        'MESSAGE_ACCESS_DENIED',
        'SOMETHING_INVENTED_LATER_ACCESS_DENIED',
      ]) {
        expect(
          friendlyFailureMessage(_api(code)),
          "You don't have permission to do that.",
          reason: code,
        );
      }
    });

    test('*_LIMIT_EXCEEDED falls back to a generic limit sentence', () {
      expect(
        friendlyFailureMessage(_api('SOME_FUTURE_LIMIT_EXCEEDED')),
        'A limit has been reached, so this action is not available.',
      );
    });
  });

  group('fallback ordering', () {
    test("an unknown code keeps the server's own message", () {
      expect(
        friendlyFailureMessage(
          _api('IDEMPOTENCY_CONFLICT', message: 'Duplicate request id'),
        ),
        'Duplicate request id',
      );
    });

    test('an unknown code with a blank message uses the caller fallback', () {
      expect(
        friendlyFailureMessage(
          _api('UNKNOWN_EXCEPTION', message: '   '),
          fallback: 'Could not load chats.',
        ),
        'Could not load chats.',
      );
    });

    test('a null error uses the caller fallback', () {
      expect(
        friendlyFailureMessage(null, fallback: 'Could not load chats.'),
        'Could not load chats.',
      );
    });
  });

  group('non-API failures still read like sentences', () {
    test('429 is phrased for a human, not as "Too Many Requests"', () {
      final message = friendlyFailureMessage(const RateLimitFailure());
      expect(message, contains('Too many attempts'));
      expect(message, isNot(contains('429')));
    });

    test('offline and timeout are distinguishable', () {
      expect(
        friendlyFailureMessage(const NetworkFailure()),
        'No internet connection. Check your network and try again.',
      );
      expect(
        friendlyFailureMessage(const TimeoutFailure()),
        'The server took too long to respond. Please try again.',
      );
    });
  });

  group('friendlyMessageForCode', () {
    test('returns null for a code it does not recognise', () {
      expect(friendlyMessageForCode('TOTALLY_UNKNOWN'), isNull);
    });

    test('recognises the session-ending codes from §2.3', () {
      for (final code in [
        'NOT_AUTHENTICATED',
        'EXPIRED_TOKEN',
        'INVALID_TOKEN',
        'TOKEN_IN_BLACKLIST',
        'NOT_FOUND_OR_INACTIVE_SESSION',
      ]) {
        expect(friendlyMessageForCode(code), isNotNull, reason: code);
        expect(friendlyMessageForCode(code), contains('sign in again'));
      }
    });
  });
}
