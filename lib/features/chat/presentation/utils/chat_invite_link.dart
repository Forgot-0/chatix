import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/utils/link_origin.dart';

/// The link that points at a public chat.
///
/// ⚠️ Composed here rather than fetched: the API has no invite resource —
/// no `POST /chats/{id}/invite/`, no public slug, nothing that mints a token
/// (api-docs §5.2 lists the whole of the chat CRUD). What it does have is
/// `POST /chats/{chat_id}/join/`, which any signed-in user may call on a
/// chat with `is_public: true`. So the only thing a link can carry is the
/// chat id, and the only thing that can act on it is this app.
///
/// That means the link is a way to pass a chat around — in a message, in an
/// email — and not a web page anyone can open. It is worded that way on
/// screen, and the gap is written down in `docs/BACKEND_GAPS.md`.
abstract final class ChatInviteLink {
  /// `https://<host>/chats/<id>` — the app's own route, on the host this
  /// build talks to.
  ///
  /// [baseUrl] defaults to the configured server so the link matches the
  /// deployment the reader is actually on; a staging build hands out staging
  /// links.
  static String of(String chatId, {String? baseUrl}) {
    final origin = linkOrigin(baseUrl ?? AppConstants.serverBaseUrl);
    return '$origin/chats/$chatId';
  }
}
