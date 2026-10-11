import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';

/// The number on the chats tab: unread messages summed over the chat list,
/// leaving out the direct chats with people the reader blocked.
///
/// ⚠️ Client-side until the backend's "этап 2" (api-docs §4.13): a blocked
/// person's messages still arrive and still raise `unread_count`, so this is
/// where they stop asking for attention. A blocked person writing in a group
/// cannot be taken out — the server counts unread per chat, not per sender.
final chatsUnreadBadgeProvider = Provider<int>((ref) {
  final quiet = ref.watch(blockedDirectChatIdsProvider);
  return ref.watch(
    chatListProvider.select(
      (state) => state.value?.totalUnreadExcept(quiet) ?? 0,
    ),
  );
});
