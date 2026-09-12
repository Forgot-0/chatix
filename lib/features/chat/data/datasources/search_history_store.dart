import 'package:chatix/core/storage/local_storage_service.dart';

/// What the search box remembers between visits.
///
/// Device-local by nature: the backend has no notion of a search history, and
/// a list of things someone typed is not something to upload on their behalf.
abstract interface class SearchHistoryStore {
  List<String> readQueries();

  Future<void> writeQueries(List<String> queries);

  /// Chat ids, most recently opened first.
  List<String> readChatIds();

  Future<void> writeChatIds(List<String> chatIds);
}

class SharedPrefsSearchHistoryStore implements SearchHistoryStore {
  SharedPrefsSearchHistoryStore(this._storage);

  static const String queriesKey = 'search.recent_queries';
  static const String chatsKey = 'search.recent_chats';

  final LocalStorageService _storage;

  @override
  List<String> readQueries() =>
      _storage.getStringList(queriesKey) ?? const <String>[];

  @override
  Future<void> writeQueries(List<String> queries) =>
      _write(queriesKey, queries);

  @override
  List<String> readChatIds() =>
      _storage.getStringList(chatsKey) ?? const <String>[];

  @override
  Future<void> writeChatIds(List<String> chatIds) => _write(chatsKey, chatIds);

  Future<void> _write(String key, List<String> values) async {
    if (values.isEmpty) {
      await _storage.remove(key);
      return;
    }
    await _storage.setStringList(key, values);
  }
}

/// The fallback for where shared preferences were never wired up — widget
/// tests, mostly.
class InMemorySearchHistoryStore implements SearchHistoryStore {
  InMemorySearchHistoryStore({
    List<String>? queries,
    List<String>? chatIds,
  }) : _queries = [...?queries],
       _chatIds = [...?chatIds];

  List<String> _queries;
  List<String> _chatIds;

  @override
  List<String> readQueries() => [..._queries];

  @override
  Future<void> writeQueries(List<String> queries) async =>
      _queries = [...queries];

  @override
  List<String> readChatIds() => [..._chatIds];

  @override
  Future<void> writeChatIds(List<String> chatIds) async =>
      _chatIds = [...chatIds];
}
