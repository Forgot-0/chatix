library;

import 'dart:convert';

import 'package:chatix/core/utils/logger.dart';

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

  if (!trimmed.startsWith('{')) return null;

  try {
    final decoded = jsonDecode(trimmed);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  } catch (error) {
    Logger.debug('Response body looked like JSON but did not parse: $error');
    return null;
  }
}

Map<String, dynamic>? readErrorEnvelope(Object? data) {
  final body = decodeResponseBody(data);
  if (body == null) return null;

  final error = body['error'];
  return error is Map ? error.cast<String, dynamic>() : null;
}

String? readErrorCode(Object? data) {
  final code = readErrorEnvelope(data)?['code'];
  return code is String && code.isNotEmpty ? code : null;
}
