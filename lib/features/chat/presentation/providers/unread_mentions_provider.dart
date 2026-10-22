import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/utils/mention_syntax.dart';
import 'package:chatix/features/chat/presentation/utils/unread_mentions.dart';

/// The signed-in reader as a mention sees them: an id to skip their own
/// messages by, and the handle others would write after the `@`.
typedef MentionReader = ({int id, String handle});

/// Null while nobody is signed in, and for a username no message could
/// mention so that it reads back (see [MentionSyntax.isMentionable]).
final mentionReaderProvider = Provider<MentionReader?>((ref) {
  final user = ref.watch(authProvider.select((auth) => auth.value));
  if (user == null || !MentionSyntax.isMentionable(user.username)) return null;
  return (id: user.id, handle: user.username);
});

/// The newest message per chat that mentioned the reader, among those that
/// came over the socket since the app started — new messages and edits,
/// the two events that carry a whole `MessageDTO` (api-docs §6.4).
///
/// Only ever grows. Whether a recorded mention is still unread is the row's
/// question ([UnreadMentions.isUnread]), answered against its own read
/// position, so nothing here has to be cleared when a chat is read.
class LiveMentionsController extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    final reader = ref.watch(mentionReaderProvider);
    if (reader == null) return const <String, int>{};

    final subscription = ref
        .read(chatSocketServiceProvider)
        .events
        .listen((event) => _onEvent(event, reader));
    ref.onDispose(subscription.cancel);

    return const <String, int>{};
  }

  void _onEvent(WSEvent event, MentionReader reader) {
    final (chatId, raw) = switch (event) {
      NewMessage(:final chatId, :final message) => (chatId, message),
      MessageEdited(:final chatId, :final message) => (chatId, message),
      _ => (null, null),
    };
    if (chatId == null || raw == null) return;

    final MessageModel model;
    try {
      model = MessageModel.fromJson(raw);
    } catch (error) {
      Logger.warning('Mentions: bad message payload: $error');
      return;
    }

    final seq = UnreadMentions.newestMentionSeq(
      [model.toEntity()],
      myUserId: reader.id,
      handle: reader.handle,
    );
    if (seq == null) return;

    final known = state[chatId];
    if (known != null && known >= seq) return;
    state = {...state, chatId: seq};
  }
}

final liveMentionsProvider =
    NotifierProvider<LiveMentionsController, Map<String, int>>(
      LiveMentionsController.new,
    );

/// The newest mention of the reader among the messages this device keeps
/// for a chat — what was loaded the last time it was open, or replayed into
/// it since.
///
/// Read once per chat and kept: the cache only grows while the chat is
/// open, and an open chat is a read one, so a newer answer would only ever
/// be one [UnreadMentions.isUnread] turns down. Mentions that arrive later
/// come over the socket ([liveMentionsProvider]).
final cachedMentionSeqProvider = Provider.family<int?, String>((ref, chatId) {
  final reader = ref.watch(mentionReaderProvider);
  if (reader == null) return null;

  return UnreadMentions.newestMentionSeq(
    ref.read(getLocalMessagesUseCaseProvider).execute(chatId),
    myUserId: reader.id,
    handle: reader.handle,
  );
});

/// Whether [chat]'s row should carry the `@`: among its unread messages is
/// one that mentions the reader, as far as this device has seen.
///
/// Looks no further than a chat with something unread — that is the only
/// kind that can answer yes, and the cache is not read for the rest.
bool watchHasUnreadMention(WidgetRef ref, ChatEntity chat) {
  if ((chat.unreadCount ?? 0) <= 0) return false;

  final reader = ref.watch(mentionReaderProvider);
  if (reader == null) return false;

  final seqs = [
    UnreadMentions.newestMentionSeq(
      [chat.lastMessage],
      myUserId: reader.id,
      handle: reader.handle,
    ),
    ref.watch(liveMentionsProvider.select((seen) => seen[chat.id])),
    ref.watch(cachedMentionSeqProvider(chat.id)),
  ].nonNulls;

  if (seqs.isEmpty) return false;
  return UnreadMentions.isUnread(chat, seqs.reduce(math.max));
}
