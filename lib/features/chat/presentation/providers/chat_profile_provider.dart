import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/chat_shared_content.dart';

/// How deep the shared-content tabs can see.
///
/// The message cache keeps 200 messages per chat, so asking for more would
/// only ever return the same list; asking for fewer would hide media the
/// reader could scroll to in the feed itself.
const int _sharedContentWindow = 200;

/// The chat's media, files, links and voice messages, newest first.
///
/// ⚠️ There is no shared-media endpoint in the API — attachments are only
/// reachable through the message that carried them (api-docs §5.4/§5.5) — so
/// this is assembled on the device from two overlapping views of the same
/// history: the window the feed has loaded, and what the local cache holds.
/// Neither is the whole chat, and the tabs say so.
///
/// The cache is read once, when the panel opens: it is a synchronous read of
/// what is already on disk, and it does not change under us while the screen
/// is up. The feed is watched, so a photo arriving over the socket shows up
/// in the Media tab without a refresh — but only while the chat screen
/// behind this one is alive, which is why the cache is read at all.
final chatSharedContentProvider = Provider.autoDispose
    .family<ChatSharedContent, String>((ref, chatId) {
      final cached = ref
          .read(getLocalMessagesUseCaseProvider)
          .execute(chatId, limit: _sharedContentWindow);

      final detail = chatDetailProvider(chatId);
      final live = ref.exists(detail)
          ? ref.watch(detail.select((s) => s.value?.messages)) ??
                const <MessageEntity>[]
          : const <MessageEntity>[];

      return ChatSharedContent.of(mergeSharedContentSources(live, cached));
    });

/// This reader's own settings for one chat: pinned, archived, silenced.
///
/// `GET /chats/{chat_id}/` answers with `ChatDetailDTO`, which has no state
/// block at all (api-docs §5.2) — the mute deadline is a field of the list
/// row and of nothing else. So the row is the only place to read it from,
/// and when the list is not up there is genuinely nothing to read: the
/// answer is null, not "not muted".
///
/// The list is watched only if it is already alive. Starting it from here
/// would turn opening a chat profile by link into a fetch of the whole chat
/// list, which is a lot of request for one switch.
final chatRowStateProvider = Provider.autoDispose
    .family<ChatStateEntity?, String>((ref, chatId) {
      for (final provider in [chatListProvider, archivedChatListProvider]) {
        if (!ref.exists(provider)) continue;

        final state = ref.watch(
          provider.select((value) => _rowStateOf(value.value, chatId)),
        );
        if (state != null) return state;
      }
      return null;
    });

ChatStateEntity? _rowStateOf(ChatListState? list, String chatId) {
  for (final chat in list?.items ?? const <ChatEntity>[]) {
    if (chat.id == chatId) return chat.state;
  }
  return null;
}

/// A request from elsewhere in the app to open the search field over a chat.
///
/// In-chat search lives in the chat screen's own app bar, so a button on
/// another screen has no way to reach for it directly. This is the way: the
/// caller names the chat and goes back to it, and the chat screen — which is
/// listening — opens the field and clears the request.
class ChatSearchRequest extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String chatId) => state = chatId;

  /// Called by the chat screen once it has acted on the request.
  void clear() => state = null;
}

final chatSearchRequestProvider =
    NotifierProvider<ChatSearchRequest, String?>(ChatSearchRequest.new);
