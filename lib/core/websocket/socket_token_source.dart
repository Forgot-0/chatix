/// Where the socket gets an access token it can actually connect with.
///
/// The token goes in the connect URL (api-docs §6.1) and lives five minutes
/// (§0), so "the token in storage" and "a token that will be accepted" are
/// not the same thing — on a reconnect after a long outage they are almost
/// never the same thing. This is the difference: a source can renew, storage
/// can only remember.
///
/// Narrow on purpose. `core/websocket` must not know how a session is
/// refreshed, only that asking can produce a better token than it has.
abstract interface class SocketTokenSource {
  /// A token good to connect with now, or null when the session is over.
  ///
  /// [forceRefresh] is for the case where the server has already said no —
  /// a `1008` close — and the stored token therefore cannot be trusted even
  /// if it still looks unexpired.
  Future<String?> token({bool forceRefresh = false});
}
