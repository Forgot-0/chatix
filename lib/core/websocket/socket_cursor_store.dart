/// Where the socket's per-chat resume cursors live between runs.
///
/// `resume` after a reconnect is only as good as the `last_seq` it carries
/// (api-docs §6.3): with the right one the gateway replays exactly what was
/// missed, with none it replays nothing and the gap stays a gap. Holding
/// them in memory covers a reconnect; holding them here covers the app being
/// killed, which is the longer outage of the two.
///
/// Deliberately narrow, and deliberately not a repository: the socket lives
/// in `core` and must not know what a chat is, let alone which feature owns
/// the store behind this.
abstract interface class SocketCursorStore {
  /// Every known cursor, as `{chat_id: last_seq}`.
  Map<String, int> load();

  /// Records that [chatId] is known up to [seq]. Never moves a cursor back.
  void save(String chatId, int seq);
}
