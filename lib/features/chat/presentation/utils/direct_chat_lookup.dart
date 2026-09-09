import 'package:chatix/features/chat/domain/entities/chat_entity.dart';

/// Finds an existing 1:1 chat with [peerUserId] among already-loaded chats.
///
/// The backend does not protect against duplicates: `409 DIRECT_CHAT_EXISTS`
/// is documented but never actually raised, so a second `POST /chats/` with
/// `chat_type: "direct"` to the same person silently creates a second chat
/// (api-docs §5.2). api-docs itself says the dedup has to happen client-side,
/// before the create call — this is that check.
///
/// It can only see the pages the client has loaded, so a miss is not proof the
/// chat does not exist. Callers should treat a miss as "go ahead and create"
/// and keep reading `DIRECT_CHAT_EXISTS` as a belt-and-braces fallback.
ChatEntity? findDirectChatWith(
  Iterable<ChatEntity> chats,
  int peerUserId, {
  required int? myUserId,
}) {
  for (final chat in chats) {
    if (chat.type != ChatType.direct) continue;

    // The roster is authoritative when it is there.
    final members = chat.members;
    if (members != null) {
      final hasPeer = members.any((m) => m.userId == peerUserId);
      if (hasPeer) return chat;
      continue;
    }

    // A list row carries no roster, only the last message's author profile.
    if (chat.peerProfile(myUserId)?.userId == peerUserId) return chat;
  }

  return null;
}
