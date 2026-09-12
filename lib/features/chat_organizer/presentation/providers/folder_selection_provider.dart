import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organized_chats.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';

/// Which tab of the strip is showing. Null is "all chats", the tab that is
/// always there and is not a folder.
///
/// The choice lives for as long as the app does, not longer: it is a view,
/// not a preference, and coming back to a fresh launch on the full list is
/// the least surprising thing the screen can do. A folder that is deleted
/// while selected drops the selection instead of showing an empty tab.
class ActiveFolderController extends Notifier<String?> {
  String? _requested;

  @override
  String? build() => _resolve(ref.watch(organizerDataProvider));

  void select(String? folderId) {
    _requested = folderId;
    state = _resolve(ref.read(organizerDataProvider));
  }

  String? _resolve(ChatOrganizerData data) {
    final requested = _requested;
    if (requested == null) return null;
    return data.folderById(requested) == null ? null : requested;
  }
}

final activeFolderProvider = NotifierProvider<ActiveFolderController, String?>(
  ActiveFolderController.new,
);

/// The folder the list is currently filtered by, if any.
final activeChatFolderProvider = Provider<ChatFolder?>(
  (ref) => ref
      .watch(organizerDataProvider)
      .folderById(ref.watch(activeFolderProvider)),
);

/// Everything the rules need beyond the chat row itself.
///
/// `now` is read when this is rebuilt rather than on every evaluation, so a
/// "no reply for N days" folder turns over as the list does — which is often
/// enough, and keeps the whole strip from re-filtering on a clock tick.
final chatRuleContextProvider = Provider<ChatRuleContext>((ref) {
  final organizer = ref.watch(organizerDataProvider);

  return ChatRuleContext(
    now: DateTime.now(),
    myUserId: ref.watch(authProvider.select((user) => user.value?.id)),
    pinnedChatIds: organizer.pinnedChatIds,
  );
});

/// How much unread sits behind each tab, keyed by folder id.
final folderUnreadCountsProvider = Provider<Map<String, int>>((ref) {
  final chats = ref.watch(chatListProvider).value?.items ?? const [];

  return folderUnreadCounts(
    chats: chats,
    organizer: ref.watch(organizerDataProvider),
    context: ref.watch(chatRuleContextProvider),
    mutedChatIds: ref.watch(chatLocalPrefsProvider).muted,
  );
});

/// Everything still unread in the list proper — what the "all chats" tab
/// carries. Archived and silenced chats stay out of it for the same reason
/// they stay out of the per-folder counts.
final visibleUnreadCountProvider = Provider<int>((ref) {
  final chats = ref.watch(chatListProvider).value?.items ?? const [];
  final organizer = ref.watch(organizerDataProvider);
  final muted = ref.watch(chatLocalPrefsProvider).muted;

  var total = 0;
  for (final chat in chats) {
    if (organizer.isArchived(chat.id)) continue;
    if (muted.contains(chat.id)) continue;
    total += chat.unreadCount ?? 0;
  }
  return total;
});
