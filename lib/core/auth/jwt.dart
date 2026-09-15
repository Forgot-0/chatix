import 'dart:convert';

/// Just enough JWT to know when a token stops being worth sending.
///
/// The access token lives five minutes (api-docs §0), and the only thing on
/// the client that can say whether the one in storage is still inside that
/// window is the token itself. Nothing here verifies a signature — that is
/// the server's job, and a client that trusted its own verification would be
/// trusting a value it also stores.
abstract final class Jwt {
  /// When [token] stops being accepted, or null if it does not say.
  ///
  /// Null on anything unexpected — a malformed token, a missing `exp`, a
  /// payload that is not an object. Every caller reads that as "cannot tell",
  /// which is the safe answer: it leads to asking the server rather than to
  /// assuming the token is good.
  static DateTime? expiry(String? token) {
    final payload = _payload(token);
    final exp = payload?['exp'];
    if (exp is! num) return null;

    return DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
  }

  /// Whether [token] is past its expiry, or close enough to it that a request
  /// sent now could arrive after it.
  ///
  /// [margin] is that "close enough". A token that expires while the frame
  /// carrying it is in flight is refused exactly like an expired one, and on
  /// a socket handshake the refusal costs a whole reconnect cycle rather than
  /// one retried request.
  static bool isExpired(
    String? token, {
    Duration margin = const Duration(seconds: 30),
    DateTime? now,
  }) {
    if (token == null || token.isEmpty) return true;

    final expiresAt = expiry(token);
    // A token that will not say when it expires is not treated as expired:
    // the server is the authority, and guessing "expired" here would mean
    // refreshing before every single connect.
    if (expiresAt == null) return false;

    final at = (now ?? DateTime.now()).toUtc();
    return !expiresAt.isAfter(at.add(margin));
  }

  static Map<String, dynamic>? _payload(String? token) {
    if (token == null || token.isEmpty) return null;

    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final decoded = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
