import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

ApiFailure _api(String code, {String message = 'server-facing text'}) =>
    ApiFailure(code: code, message: message, detail: null, status: 400);

/// Every `error.code` the table in `failure_messages.dart` claims to know.
///
/// Kept here rather than exported from the table so the two have to be
/// changed together: a code dropped from the switch fails this list.
const _knownCodes = <String>[
  'NOT_AUTHENTICATED',
  'NOT_FOUND_OR_INACTIVE_SESSION',
  'EXPIRED_TOKEN',
  'INVALID_TOKEN',
  'TOKEN_IN_BLACKLIST',
  'ACCESS_DENIED',
  'VALIDATION',
  'WRONG_LOGIN_DATA',
  'PASSWORD_MISMATCH',
  'DUPLICATE_USER',
  'EMAIL_NOT_CONFIRMED',
  'NOT_EXIST_PROVIDER_OAUTH',
  'OAUTH_STATE_NOT_FOUND',
  'LINKED_ANOTHER_USER_OAUTH',
  'ALREADE_EXIST_PROFILE',
  'NOT_CHAT_MEMBER',
  'ALREADY_CHAT_MEMBER',
  'INVALID_CHAT_ROLE',
  'DIRECT_CHAT_EXISTS',
  'MESSAGE_TOO_LONG',
  'INVALID_MESSAGE',
  'SLOW_MODE_LIMIT',
  'SLOW_MODE_OUT_OF_RANGE',
  'ATTACHMENT_LIMIT_EXCEEDED',
  'ATTACHMENT_NOT_FOUND',
  'ATTACHMENT_VALIDATION',
  'EMPTY_ATTACHMENT_UPLOAD_REQUEST',
  'INVALID_UPLOAD_TOKEN',
  'AVATAR_NOT_TYPE_IMAGE',
  'ACTIVE_CALL_EXISTS',
  'NO_ACTIVE_CALL',
  'LIVEKIT_UNAUTHORIZED',
  'LIVEKIT_ERROR',
  'INVALID_REACTION',
  'REACTION_NOT_ALLOWED',
  'REACTIONS_DISABLED',
  'TOO_MANY_REACTIONS',
  'MAX_LIMIT_CURSOR',
];

void main() {
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('the codes the UI shows most often', () {
    test('WRONG_LOGIN_DATA', () {
      expect(
        friendlyFailureMessage(_api('WRONG_LOGIN_DATA'), l10n: en),
        'Incorrect username or password.',
      );
    });

    test('ACCESS_DENIED', () {
      expect(
        friendlyFailureMessage(_api('ACCESS_DENIED'), l10n: en),
        "You don't have permission to do that.",
      );
    });

    test('MESSAGE_TOO_LONG', () {
      expect(
        friendlyFailureMessage(_api('MESSAGE_TOO_LONG'), l10n: en),
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
          friendlyFailureMessage(_api(code), l10n: en),
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
          friendlyFailureMessage(_api(code), l10n: en),
          "You don't have permission to do that.",
          reason: code,
        );
      }
    });

    test('*_LIMIT_EXCEEDED falls back to a generic limit sentence', () {
      expect(
        friendlyFailureMessage(_api('SOME_FUTURE_LIMIT_EXCEEDED'), l10n: en),
        'A limit has been reached, so this action is not available.',
      );
    });
  });

  group('fallback ordering', () {
    test("an unknown code keeps the server's own message", () {
      expect(
        friendlyFailureMessage(
          _api('IDEMPOTENCY_CONFLICT', message: 'Duplicate request id'),
          l10n: en,
        ),
        'Duplicate request id',
      );
    });

    test('an unknown code with a blank message uses the caller fallback', () {
      expect(
        friendlyFailureMessage(
          _api('UNKNOWN_EXCEPTION', message: '   '),
          l10n: en,
          fallback: 'Could not load chats.',
        ),
        'Could not load chats.',
      );
    });

    test('a null error uses the caller fallback', () {
      expect(
        friendlyFailureMessage(
          null,
          l10n: en,
          fallback: 'Could not load chats.',
        ),
        'Could not load chats.',
      );
    });

    test('with no caller fallback it still reads as a sentence', () {
      expect(
        friendlyFailureMessage(null, l10n: en),
        'Something went wrong. Please try again.',
      );
    });
  });

  group('non-API failures still read like sentences', () {
    // The strings in the data layer are diagnostics. Showing one is how
    // English reaches a reader who asked for another language.
    test('a domain failure shows its screen\'s wording, not its own', () {
      expect(
        friendlyFailureMessage(
          const ValidationFailure(message: 'Chat id is required'),
          l10n: en,
          fallback: 'Could not load this chat.',
        ),
        'Could not load this chat.',
      );

      expect(
        friendlyFailureMessage(
          const ServerFailure(message: 'Unknown error occurred'),
          l10n: en,
        ),
        'Something went wrong. Please try again.',
      );
    });

    test('429 is phrased for a human, not as "Too Many Requests"', () {
      final message = friendlyFailureMessage(
        const RateLimitFailure(),
        l10n: en,
      );
      expect(message, contains('Too many attempts'));
      expect(message, isNot(contains('429')));
    });

    test('offline and timeout are distinguishable', () {
      expect(
        friendlyFailureMessage(const NetworkFailure(), l10n: en),
        'No internet connection. Check your network and try again.',
      );
      expect(
        friendlyFailureMessage(const TimeoutFailure(), l10n: en),
        'The server took too long to respond. Please try again.',
      );
    });
  });

  group('friendlyMessageForCode', () {
    test('returns null for a code it does not recognise', () {
      expect(friendlyMessageForCode('TOTALLY_UNKNOWN', en), isNull);
    });

    test('recognises the session-ending codes from §2.3', () {
      for (final code in [
        'NOT_AUTHENTICATED',
        'EXPIRED_TOKEN',
        'INVALID_TOKEN',
        'TOKEN_IN_BLACKLIST',
        'NOT_FOUND_OR_INACTIVE_SESSION',
      ]) {
        expect(friendlyMessageForCode(code, en), isNotNull, reason: code);
        expect(friendlyMessageForCode(code, en), contains('sign in again'));
      }
    });
  });

  // The whole point of routing these through ARB: a reader in any supported
  // language gets a sentence, not the server's English log line.
  group('every supported locale answers for every known code', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test(locale.languageCode, () async {
        final l10n = await AppLocalizations.delegate.load(locale);

        for (final code in _knownCodes) {
          final message = friendlyMessageForCode(code, l10n);
          expect(message, isNotNull, reason: '$locale / $code');
          expect(message!.trim(), isNotEmpty, reason: '$locale / $code');
        }

        // And the four that have no code of their own.
        expect(l10n.failureGeneric.trim(), isNotEmpty);
        expect(l10n.failureRateLimited.trim(), isNotEmpty);
        expect(l10n.failureNoConnection.trim(), isNotEmpty);
        expect(l10n.failureTimeout.trim(), isNotEmpty);
      });
    }

    test('non-English locales are actually translated, not copied', () async {
      final english = await AppLocalizations.delegate.load(const Locale('en'));

      for (final locale in AppLocalizations.supportedLocales) {
        if (locale.languageCode == 'en') continue;
        final l10n = await AppLocalizations.delegate.load(locale);

        expect(
          l10n.apiErrorSessionEnded,
          isNot(english.apiErrorSessionEnded),
          reason: '$locale still shows the English sentence',
        );
      }
    });
  });
}
