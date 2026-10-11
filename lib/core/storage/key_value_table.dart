import 'package:hive/hive.dart';

import 'package:chatix/core/utils/logger.dart';

/// One table of a local store: string keys, string values, nothing else.
///
/// Small on purpose. Everything a cache does — the LRU over chats, the
/// per-chat trim, the outbox ordering, the contact book's upserts — is
/// written once against this interface, so the same logic runs over Hive on
/// a device and over plain maps in a test, and the storage engine stays a
/// detail that can be swapped without touching a rule.
abstract interface class LocalKeyValueTable {
  /// Every key, in insertion order.
  List<String> keys();

  String? read(String key);

  Future<void> write(String key, String value);

  /// Writes every entry of [entries] — one call, so an engine that can
  /// batch does.
  Future<void> writeAll(Map<String, String> entries);

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
  Future<void> writeAll(Map<String, String> entries) async {
    _entries.addAll(entries);
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

/// One Hive box seen as a table.
///
/// Hive rather than a SQL engine because nothing kept this way is a query:
/// every read is "this key" or "the keys under this prefix", which a
/// key-value box answers directly. Hive is also already a dependency and
/// needs no native build step on any of the six platforms this app ships to.
class HiveKeyValueTable implements LocalKeyValueTable {
  const HiveKeyValueTable(this._box);

  final Box<String> _box;

  @override
  List<String> keys() => [
    for (final key in _box.keys)
      if (key is String) key,
  ];

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> writeAll(Map<String, String> entries) => _box.putAll(entries);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<void> deleteAll(Iterable<String> keys) => _box.deleteAll(keys);

  @override
  Future<void> clear() async => _box.clear();
}

/// Opens one box, and on a corrupt file deletes it and opens a fresh one.
///
/// Meant for boxes that hold a copy of something the server still has, so
/// throwing the file away costs a refetch and nothing else. [label] names the
/// store in the log line.
Future<Box<String>> openRecoverableHiveBox(
  String name, {
  String label = 'Local store',
}) async {
  try {
    return await Hive.openBox<String>(name);
  } catch (error) {
    Logger.warning('$label: box "$name" unreadable ($error), recreating');
    await Hive.deleteBoxFromDisk(name);
    return Hive.openBox<String>(name);
  }
}
