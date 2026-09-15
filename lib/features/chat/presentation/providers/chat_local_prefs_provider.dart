import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';

/// The store behind the device-local chat odds and ends: unsent drafts, and
/// which emoji this person reaches for.
///
/// Silencing a chat used to be here. It is `is_muted_by_me` on the chat row
/// now, written through `PATCH /chats/{chat_id}/state/` (api-docs §5.2), so
/// it follows the account instead of the phone.
///
/// Shared preferences are handed to the app at startup, so anywhere they were
/// not — a widget test that pumps the list without overriding them — this
/// falls back to memory rather than taking the screen down with it.
final chatLocalPrefsStoreProvider = Provider<ChatLocalPrefsStore>((ref) {
  try {
    return SharedPrefsChatLocalPrefsStore(
      ref.watch(localStorageServiceProvider),
    );
  } catch (error) {
    Logger.debug('Chat prefs: no persistent storage, keeping them in memory');
    return InMemoryChatLocalPrefsStore();
  }
});
