import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/auth/jwt.dart';

/// The access token lives five minutes (api-docs §0). Knowing when it stops
/// being worth sending is the difference between renewing before a handshake
/// and being closed over it.
void main() {
  String token(Map<String, Object?> payload) {
    String segment(Object value) =>
        base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');

    return '${segment({'alg': 'HS256'})}.${segment(payload)}.signature';
  }

  final now = DateTime.utc(2026, 9, 15, 12);

  int seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

  test('reads the expiry out of the payload', () {
    final at = now.add(const Duration(minutes: 5));
    expect(Jwt.expiry(token({'exp': seconds(at)})), at);
  });

  test('a token with minutes left is not expired', () {
    final live = token({'exp': seconds(now.add(const Duration(minutes: 4)))});
    expect(Jwt.isExpired(live, now: now), isFalse);
  });

  test('a token already past its expiry is', () {
    final dead = token({
      'exp': seconds(now.subtract(const Duration(minutes: 1))),
    });
    expect(Jwt.isExpired(dead, now: now), isTrue);
  });

  test('one about to expire counts as expired', () {
    // It would die in flight, and a handshake refused for a stale token costs
    // a whole reconnect rather than a retried request.
    final nearly = token({
      'exp': seconds(now.add(const Duration(seconds: 10))),
    });
    expect(Jwt.isExpired(nearly, now: now), isTrue);
    expect(Jwt.isExpired(nearly, margin: Duration.zero, now: now), isFalse);
  });

  test('no token at all is expired', () {
    expect(Jwt.isExpired(null), isTrue);
    expect(Jwt.isExpired(''), isTrue);
  });

  group('anything it cannot read', () {
    test('is not guessed at', () {
      // Guessing "expired" would mean renewing before every single connect;
      // the server is the authority on a token it cannot parse.
      expect(Jwt.isExpired('not-a-jwt', now: now), isFalse);
      expect(Jwt.isExpired(token(const {}), now: now), isFalse);
    });

    test('and has no expiry to report', () {
      expect(Jwt.expiry('not-a-jwt'), isNull);
      expect(Jwt.expiry('a.b.c'), isNull);
      expect(Jwt.expiry(token({'exp': 'soon'})), isNull);
    });
  });
}
