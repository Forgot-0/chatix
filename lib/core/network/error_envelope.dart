/// Reads the api-docs §2.1 error envelope out of a response body, **whatever
/// form Dio happened to leave it in**.
///
/// ### Why this is not just `data as Map`
///
/// Dio only JSON-decodes a response when the response's own
/// `Content-Type` header is a JSON media type
/// (`Transformer.isJsonMimeType`, and `isJsonMimeType(null) == false`).
/// `ResponseType.json` on the *request* does not force it — it is a
/// precondition, not an override.
///
/// This backend's gateway serves error responses **without a `Content-Type`
/// header** while successful ones carry `application/json`. So a `200` arrives
/// as a decoded `Map` and a `400` carrying the identical JSON arrives as a raw
/// [String]. Every `data is Map` check then silently fails on exactly the
/// responses whose body matters most, and the whole §2 code catalogue —
/// `EXPIRED_TOKEN`, `SLOW_MODE_LIMIT`, the reaction errors, the access-denied
/// checks the chat providers branch on — degrades to "unknown error".
///
/// The symptom that motivated this: `400 EXPIRED_TOKEN` (§2.3 — the documented
/// refresh trigger) was unreadable, so `AuthInterceptor` never refreshed and
/// the app retried with a dead token indefinitely instead of either recovering
/// or signing out.
///
/// Decoding here rather than in a custom `Transformer` is deliberate: a
/// transformer that force-decoded every body would also hit the presigned
/// S3 uploads and binary downloads, which are not JSON and must not be
/// touched. These helpers run only where a §2.1 envelope is actually expected.
library;

import 'dart:convert';

import 'package:chatix/core/utils/logger.dart';

/// The response body as a JSON object, or `null` if it is not one.
///
/// Accepts the three shapes Dio can produce: an already-decoded [Map], a raw
/// [String] (the no-`Content-Type` case above), and a byte list
/// (`ResponseType.bytes`, used for downloads — which can fail with a JSON
/// error body just like anything else).
///
/// Never throws: a body that is not JSON at all (an HTML error page from a
/// proxy, a truncated response) yields `null`, which callers already treat as
/// "no envelope".
Map<String, dynamic>? decodeResponseBody(Object? data) {
  if (data == null) return null;

  if (data is Map) {
    return data.cast<String, dynamic>();
  }

  final String text;
  if (data is String) {
    text = data;
  } else if (data is List<int>) {
    try {
      text = utf8.decode(data, allowMalformed: true);
    } catch (_) {
      return null;
    }
  } else {
    return null;
  }

  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  // Cheap guard so an HTML error page doesn't reach the JSON parser on every
  // failed request just to throw.
  if (!trimmed.startsWith('{')) return null;

  try {
    final decoded = jsonDecode(trimmed);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  } catch (error) {
    Logger.debug('Response body looked like JSON but did not parse: $error');
    return null;
  }
}

/// `body.error` — the inner `{code, message, detail}` object of the §2.1
/// envelope. `null` when the body is not an envelope at all.
///
/// ⚠️ Not every error body has one. §2.2 lists the exceptions: a `429` is a
/// bare `{"detail": "..."}`, and a `422` validation error is a list. Callers
/// must handle `null` rather than assume the envelope is universal.
Map<String, dynamic>? readErrorEnvelope(Object? data) {
  final body = decodeResponseBody(data);
  if (body == null) return null;

  final error = body['error'];
  return error is Map ? error.cast<String, dynamic>() : null;
}

/// `body.error.code` — the stable contract clients branch on (§2.3–§2.8).
String? readErrorCode(Object? data) {
  final code = readErrorEnvelope(data)?['code'];
  return code is String && code.isNotEmpty ? code : null;
}
