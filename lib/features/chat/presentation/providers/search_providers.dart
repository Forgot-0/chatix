import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/data/datasources/search_history_store.dart';
import 'package:chatix/features/chat/data/repositories/local_message_search_repository.dart';
import 'package:chatix/features/chat/data/repositories/remote_message_search_repository.dart';
import 'package:chatix/features/chat/domain/repositories/message_search_repository.dart';
import 'package:chatix/features/chat/domain/usecases/search_messages_use_case.dart';

/// The messages this device has loaded, kept for the search to read.
///
/// Alive for as long as the app is: a cache that is thrown away when the
/// search screen closes would make the next search start from nothing.
final messageCacheStoreProvider = Provider<MessageCacheStore>(
  (ref) => InMemoryMessageCacheStore(),
);

/// The server search, with this device's own messages behind it.
///
/// `GET /chats/messages/search/` covers every chat the caller is in
/// (api-docs §5.4.1). The cache is not a second opinion, only a last resort
/// for a request that could not be made at all; when it answers, the result
/// says so and the screen tells the reader.
final messageSearchRepositoryProvider = Provider<MessageSearchRepository>((
  ref,
) {
  return OfflineFallbackMessageSearchRepository(
    remote: RemoteMessageSearchRepository(ref.watch(chatRestDataSourceProvider)),
    local: LocalMessageSearchRepository(ref.watch(messageCacheStoreProvider)),
  );
});

final searchMessagesUseCaseProvider = Provider<SearchMessagesUseCase>(
  (ref) => SearchMessagesUseCase(ref.watch(messageSearchRepositoryProvider)),
);

/// Where recent searches and recently opened chats are kept.
///
/// Falls back to memory where shared preferences were never wired up — a
/// widget test, mostly — rather than taking the screen down with it.
final searchHistoryStoreProvider = Provider<SearchHistoryStore>((ref) {
  try {
    return SharedPrefsSearchHistoryStore(
      ref.watch(localStorageServiceProvider),
    );
  } catch (error) {
    Logger.debug('Search history: no persistent storage, keeping it in memory');
    return InMemorySearchHistoryStore();
  }
});
