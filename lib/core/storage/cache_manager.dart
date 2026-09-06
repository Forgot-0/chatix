import 'dart:collection';

class CacheManager<T> {
  final int maxItems;
  final Map<String, _CacheEntry<T>> _cache;
  final LinkedList<_CacheEntry<T>> _lruList;

  CacheManager({this.maxItems = 100})
    : _cache = {},
      _lruList = LinkedList<_CacheEntry<T>>();

  void setItem(String key, T value) {
    if (_cache.containsKey(key)) {
      final entry = _cache[key]!;
      entry.unlink();
      _cache.remove(key);
    }

    if (_cache.length >= maxItems && _lruList.isNotEmpty) {
      final leastUsed = _lruList.last;
      _cache.remove(leastUsed.key);
      leastUsed.unlink();
    }

    final entry = _CacheEntry<T>(key, value);
    _cache[key] = entry;
    _lruList.addFirst(entry);
  }

  T? getItem(String key) {
    final entry = _cache[key];
    if (entry == null) {
      return null;
    }

    entry.unlink();
    _lruList.addFirst(entry);

    return entry.value;
  }

  bool containsKey(String key) => _cache.containsKey(key);

  void removeItem(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      entry.unlink();
    }
  }

  void clear() {
    _cache.clear();
    _lruList.clear();
  }

  int get length => _cache.length;

  bool get isEmpty => _cache.isEmpty;

  bool get isNotEmpty => _cache.isNotEmpty;

  Iterable<String> get keys => _cache.keys;

  Iterable<T> get values => _lruList.map((entry) => entry.value);
}

base class _CacheEntry<T> extends LinkedListEntry<_CacheEntry<T>> {
  final String key;
  final T value;

  _CacheEntry(this.key, this.value);
}
