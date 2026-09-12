import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/data/datasources/search_history_store.dart';
import 'package:chatix/features/chat/data/repositories/local_message_search_repository.dart';
import 'package:chatix/features/chat/domain/repositories/message_search_repository.dart';
import 'package:chatix/features/chat/domain/usecases/search_messages_use_case.dart';

/// The messages this device has loaded, kept for the search to read.
///
/// Alive for as long as the app is: a cache that is thrown away when the
/// search screen closes would make the next search start from nothing.
final messageCacheStoreProvider = Provider<MessageCacheStore>(
  (ref) => InMemoryMessageCacheStore(),
);

/// The one line to change when the backend grows a message search.
///
/// Point it at a remote implementation and every screen above follows: the
/// results carry their own [MessageSearchSource], so the "loaded history
/// only" notice disappears without anyone editing a widget.
final messageSearchRepositoryProvider = Provider<MessageSearchRepository>(
  (ref) => LocalMessageSearchRepository(ref.watch(messageCacheStoreProvider)),
);

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
