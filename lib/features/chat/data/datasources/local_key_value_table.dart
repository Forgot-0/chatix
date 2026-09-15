/// One table of the local store: string keys, string values, nothing else.
///
/// Small on purpose. Everything the cache does — the LRU over chats, the
/// per-chat trim, the outbox ordering — is written once against this
/// interface, so the same logic runs over Hive on a device and over plain
/// maps in a test, and the storage engine stays a detail that can be swapped
/// without touching a rule.
abstract interface class LocalKeyValueTable {
  /// Every key, in insertion order.
  List<String> keys();

  String? read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> deleteAll(Iterable<String> keys);

  Future<void> clear();
}

/// The table used where there is no disk: tests, and any platform the real
/// store could not be opened on. Behaves identically, forgets everything on
/// exit.
class MemoryKeyValueTable implements LocalKeyValueTable {
  final Map<String, String> _entries = <String, String>{};

  @override
  List<String> keys() => _entries.keys.toList();

  @override
  String? read(String key) => _entries[key];

  @override
  Future<void> write(String key, String value) async {
    _entries[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _entries.remove(key);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    for (final key in keys) {
      _entries.remove(key);
    }
  }

  @override
  Future<void> clear() async => _entries.clear();
}
