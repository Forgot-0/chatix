import 'package:equatable/equatable.dart';

import 'package:chatix/core/utils/text_match.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';

/// Which part of a chat the query was found in.
///
/// The field decides both how the row explains itself and how it is ranked:
/// someone typing a name means the chat called that, not the one whose
/// description happens to mention it.
enum ChatMatchField { title, peer, description }

/// One chat from the loaded list that matched.
class ChatSearchHit extends Equatable {
  const ChatSearchHit({
    required this.chat,
    required this.field,
    required this.matchedText,
  });

  /// A chat standing on its own, with nothing matched in it.
  ///
  /// What the recently-opened list is made of: the same row as a result, so
  /// the screen does not change shape when the field starts being typed in.
  factory ChatSearchHit.plain(ChatEntity chat) => ChatSearchHit(
    chat: chat,
    field: ChatMatchField.title,
    matchedText: chat.name?.trim() ?? '',
  );

  final ChatEntity chat;

  final ChatMatchField field;

  /// The text the match was found in, so the row can show the description
  /// line that explains an otherwise puzzling result.
  final String matchedText;

  bool get isTitleMatch => field != ChatMatchField.description;

  @override
  List<Object?> get props => [chat, field, matchedText];
}

/// Searches the chats already on the device by name, by the other person's
/// name, and by description.
///
/// Deliberately not the last message: that is the messages tab's job, and a
/// chat row that matched on something invisible reads as a bug.
List<ChatSearchHit> searchLoadedChats(
  List<ChatEntity> chats,
  String query, {
  int? myUserId,
}) {
  final needle = query.trim();
  if (needle.isEmpty) return const <ChatSearchHit>[];

  final titles = <ChatSearchHit>[];
  final descriptions = <ChatSearchHit>[];

  for (final chat in chats) {
    final name = chat.name?.trim() ?? '';
    if (containsIgnoreCase(name, needle)) {
      titles.add(
        ChatSearchHit(
          chat: chat,
          field: ChatMatchField.title,
          matchedText: name,
        ),
      );
      continue;
    }

    final peer = chat.peerName(myUserId)?.trim() ?? '';
    if (containsIgnoreCase(peer, needle)) {
      titles.add(
        ChatSearchHit(
          chat: chat,
          field: ChatMatchField.peer,
          matchedText: peer,
        ),
      );
      continue;
    }

    final description = chat.description?.trim() ?? '';
    if (containsIgnoreCase(description, needle)) {
      descriptions.add(
        ChatSearchHit(
          chat: chat,
          field: ChatMatchField.description,
          matchedText: description,
        ),
      );
    }
  }

  // Name matches first, and inside each group the order the server sent
  // (`last_activity_at` descending, api-docs §5.2) is left alone.
  return [...titles, ...descriptions];
}
