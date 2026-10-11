import 'package:equatable/equatable.dart';

/// Whose messages must not interrupt the reader: the people they blocked,
/// and the direct chats with those people.
///
/// ⚠️ A client-side rule, and only until the backend's "этап 2": a block is
/// kept on the server (api-docs §4.13) but chats do not check it yet, so a
/// blocked person's message is delivered — over the socket and as a push —
/// like anyone else's. This is what keeps it quiet on arrival.
///
/// Both halves are needed because push payloads are not typed (api-docs
/// §7.2): one that names its sender is caught by [userIds], one that only
/// names its chat is caught by [directChatIds]. A group message from a
/// blocked person whose push does not name the sender cannot be recognised
/// at all.
class BlockedSenders extends Equatable {
  const BlockedSenders({
    this.userIds = const <int>{},
    this.directChatIds = const <String>{},
  });

  static const BlockedSenders none = BlockedSenders();

  final Set<int> userIds;

  /// Direct chats whose other member is in [userIds].
  final Set<String> directChatIds;

  bool get isEmpty => userIds.isEmpty && directChatIds.isEmpty;

  /// Whether a message from [senderId] in [chatId] comes from somebody
  /// blocked. Either may be unknown.
  bool covers({int? senderId, String? chatId}) {
    if (senderId != null && userIds.contains(senderId)) return true;
    if (chatId != null && directChatIds.contains(chatId)) return true;
    return false;
  }

  Map<String, Object?> toJson() => {
    'user_ids': (userIds.toList()..sort()),
    'direct_chat_ids': (directChatIds.toList()..sort()),
  };

  static BlockedSenders fromJson(Map<String, Object?> json) => BlockedSenders(
    userIds: {
      for (final id in json['user_ids'] as List? ?? const <Object?>[])
        if (id is int) id,
    },
    directChatIds: {
      for (final id in json['direct_chat_ids'] as List? ?? const <Object?>[])
        if (id is String && id.isNotEmpty) id,
    },
  );

  @override
  List<Object?> get props => [userIds, directChatIds];
}
