import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/network/error_envelope.dart';

/// Covers the api-docs §2.1 envelope reader.
///
/// The case that matters is the [String] one: Dio only JSON-decodes a body
/// whose *response* carries a JSON `Content-Type`, and this backend's gateway
/// omits that header on error responses while sending it on successful ones.
/// So the identical JSON arrives as a `Map` on a 200 and as a raw `String` on
/// a 400 — and a reader that only handles `Map` goes blind exactly where the
/// error codes live.
void main() {
  const envelope = {
    'error': {
      'code': 'EXPIRED_TOKEN',
      'message': 'Token has expired',
      'detail': <String, dynamic>{},
    },
    'status': 400,
    'request_id': '8b330a0f-db07-4fd5-9cef-1d23cefbca61',
    'timestamp': 1788557769.449433,
  };

  group('decodeResponseBody', () {
    test('passes an already-decoded Map straight through', () {
      expect(decodeResponseBody(envelope)?['status'], 400);
    });

    test('decodes a raw JSON String — the no-Content-Type case', () {
      final body = jsonEncode(envelope);

      expect(decodeResponseBody(body)?['status'], 400);
    });

    test('decodes a byte list, for ResponseType.bytes requests', () {
      final bytes = utf8.encode(jsonEncode(envelope));

      expect(decodeResponseBody(bytes)?['status'], 400);
    });

    test('tolerates surrounding whitespace', () {
      expect(decodeResponseBody('  ${jsonEncode(envelope)}\n'), isNotNull);
    });

    test('returns null — never throws — for bodies that are not JSON', () {
      // A proxy's HTML error page, an empty body, a bare string, a JSON array.
      for (final body in <Object?>[
        null,
        '',
        '   ',
        '<html><body>502 Bad Gateway</body></html>',
        'Internal Server Error',
        '[1, 2, 3]',
        42,
      ]) {
        expect(
          () => decodeResponseBody(body),
          returnsNormally,
          reason: 'body $body must not throw',
        );
        expect(decodeResponseBody(body), isNull, reason: 'body $body');
      }
    });

    test('returns null for a truncated JSON object rather than throwing', () {
      expect(decodeResponseBody('{"error": {"code": "EXPIR'), isNull);
    });
  });

  group('readErrorCode', () {
    test('reads the code from a String body, which is the real wire form', () {
      // The regression this whole file exists for: this returning null is what
      // stopped AuthInterceptor from ever refreshing.
      expect(readErrorCode(jsonEncode(envelope)), 'EXPIRED_TOKEN');
    });

    test('reads the code from a Map body', () {
      expect(readErrorCode(envelope), 'EXPIRED_TOKEN');
    });

    test('returns null when there is no envelope', () {
      // §2.2: a 429 is a bare `{"detail": "..."}` with no `error` object, and
      // a 422 validation body is a list. Neither has a code.
      expect(readErrorCode('{"detail": "Too Many Requests"}'), isNull);
      expect(readErrorCode('{}'), isNull);
      expect(readErrorCode(null), isNull);
    });

    test('an empty or non-string code reads as absent', () {
      expect(readErrorCode('{"error": {"code": ""}}'), isNull);
      expect(readErrorCode('{"error": {"code": 42}}'), isNull);
      expect(readErrorCode('{"error": "not an object"}'), isNull);
    });
  });

  group('readErrorEnvelope', () {
    test('returns the inner object, with message and detail intact', () {
      final error = readErrorEnvelope(jsonEncode(envelope));

      expect(error?['code'], 'EXPIRED_TOKEN');
      expect(error?['message'], 'Token has expired');
      expect(error?['detail'], <String, dynamic>{});
    });

    test('carries a populated detail through — callers branch on it', () {
      // e.g. §2.7 SLOW_MODE_LIMIT's `retry_after`, or TOO_MANY_REACTIONS'
      // `scope`, both of which change what the UI says.
      const body =
          '{"error": {"code": "SLOW_MODE_LIMIT", "message": "Slow mode", '
          '"detail": {"chat_id": "c1", "retry_after": 30}}}';

      final detail = readErrorEnvelope(body)?['detail'] as Map?;
      expect(detail?['retry_after'], 30);
    });
  });
}
