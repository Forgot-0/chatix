import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/network/error_envelope.dart';

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
      expect(readErrorCode(jsonEncode(envelope)), 'EXPIRED_TOKEN');
    });

    test('reads the code from a Map body', () {
      expect(readErrorCode(envelope), 'EXPIRED_TOKEN');
    });

    test('returns null when there is no envelope', () {
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
      const body =
          '{"error": {"code": "SLOW_MODE_LIMIT", "message": "Slow mode", '
          '"detail": {"chat_id": "c1", "retry_after": 30}}}';

      final detail = readErrorEnvelope(body)?['detail'] as Map?;
      expect(detail?['retry_after'], 30);
    });
  });
}
