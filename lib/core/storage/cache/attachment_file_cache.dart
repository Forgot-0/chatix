import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import 'package:chatix/core/utils/logger.dart';

/// Downloaded attachments, kept on disk under their `s3_key`.
///
/// The key is the whole point. `AttachmentDTO.url` is a presigned link that
/// dies after 300 seconds (api-docs §5.5), so caching by URL would mean a
/// fresh copy of the same bytes every five minutes and a cache that never
/// hits. `s3_key` names the object itself and never changes, so a file
/// downloaded once is reused for as long as it survives eviction, however
/// many links have come and gone in between.
///
/// Eviction is size-based and least-recently-used: every [find] touches the
/// file, and [store] trims the oldest until the directory is back under
/// [maxBytes]. Nothing here expires on a clock — an object under a given key
/// is immutable, so an old copy is never a stale one.
class AttachmentFileCache {
  AttachmentFileCache({
    Future<Directory> Function()? rootDirectory,
    this.maxBytes = defaultMaxBytes,
  }) : _rootDirectory = rootDirectory ?? _defaultRoot;

  /// How much disk the cache may hold before the oldest files are dropped.
  static const int defaultMaxBytes = 256 * 1024 * 1024;

  /// Trimming goes this far below [maxBytes] rather than stopping right at
  /// it, so one eviction covers the next few downloads instead of every
  /// single store paying for a directory walk.
  static const double _trimTo = 0.8;

  static const String _directoryName = 'chat_attachments';

  final Future<Directory> Function() _rootDirectory;
  final int maxBytes;

  /// Guards the one-time directory resolution.
  final Lock _lock = Lock();

  /// Guards eviction. Separate from [_lock] because trimming walks the
  /// directory, which resolves it — one non-reentrant lock would deadlock.
  final Lock _trimLock = Lock();

  Directory? _resolved;

  static Future<Directory> _defaultRoot() async {
    try {
      return await getApplicationCacheDirectory();
    } catch (_) {
      // Not every platform has a dedicated cache directory; a temporary one
      // is the same trade (the OS may reclaim it, and the file is
      // re-downloadable).
      return getTemporaryDirectory();
    }
  }

  /// The directory holding the cached files, created on first use.
  Future<Directory> directory() async {
    final existing = _resolved;
    if (existing != null) return existing;

    return _lock.synchronized(() async {
      final alreadyResolved = _resolved;
      if (alreadyResolved != null) return alreadyResolved;

      final root = await _rootDirectory();
      final directory = Directory('${root.path}/$_directoryName');
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }

      _resolved = directory;
      return directory;
    });
  }

  /// The cached file for [s3Key], or null when it has never been downloaded
  /// or has since been evicted.
  Future<File?> find(String s3Key) async {
    try {
      final file = await _fileFor(s3Key);
      if (!file.existsSync()) return null;

      // Touch it so a file that is still being looked at outlives one that
      // was downloaded later and forgotten.
      await _touch(file);
      return file;
    } on FileSystemException catch (error) {
      Logger.warning('Attachment cache: could not read $s3Key ($error)');
      return null;
    }
  }

  /// Writes [bytes] under [s3Key] and answers with the file they landed in.
  Future<File> store(String s3Key, List<int> bytes) async {
    final file = await _fileFor(s3Key);

    // Written beside the target and renamed, so a download interrupted
    // halfway cannot leave a truncated file that later reads as a hit.
    final temporary = File('${file.path}.part');
    await temporary.writeAsBytes(bytes, flush: true);
    if (file.existsSync()) {
      await file.delete();
    }
    await temporary.rename(file.path);

    unawaited(_trim());
    return file;
  }

  /// Everything the cache is currently holding, in bytes.
  Future<int> usedBytes() async {
    final entries = await _entries();
    return entries.fold<int>(0, (sum, entry) => sum + entry.size);
  }

  Future<void> clear() async {
    final directory = await this.directory();

    try {
      await for (final entity in directory.list()) {
        if (entity is File) await entity.delete();
      }
    } on FileSystemException {
      // Gone already, or going: either way there is nothing left to clear.
    }
  }

  Future<File> _fileFor(String s3Key) async {
    final directory = await this.directory();
    return File('${directory.path}/${fileNameFor(s3Key)}');
  }

  /// The on-disk name for an object key.
  ///
  /// A key is `chats/{chat_id}/{uuid4}/{clean_filename}` (api-docs §5.5) —
  /// too long and too full of separators to be a filename, so it is hashed.
  /// The extension is carried over unhashed so the platform can still tell
  /// what the file is when it is handed to a viewer or saved.
  static String fileNameFor(String s3Key) {
    final digest = _fnv1a64(s3Key).toRadixString(16).padLeft(16, '0');

    final name = s3Key.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return digest;

    final extension = name
        .substring(dot + 1)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (extension.isEmpty || extension.length > 8) return digest;

    return '$digest.$extension';
  }

  /// FNV-1a, 64-bit, over the key's UTF-16 code units.
  ///
  /// Hand-rolled rather than `String.hashCode` because the name has to mean
  /// the same thing across runs and across releases, which `hashCode`
  /// explicitly does not promise.
  static int _fnv1a64(String value) {
    const int prime = 0x100000001b3;
    var hash = 0xcbf29ce484222325;

    for (final unit in value.codeUnits) {
      hash ^= unit & 0xFF;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
      hash ^= (unit >> 8) & 0xFF;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }

    return hash;
  }

  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } on FileSystemException {
      // Some filesystems refuse this; LRU degrades to insertion order.
    } on UnsupportedError {
      // Same, on platforms where the operation does not exist at all.
    }
  }

  /// Never throws: it runs unawaited behind [store], and the cache
  /// directory is one the OS may empty or remove at any moment.
  Future<void> _trim() async {
    await _trimLock.synchronized(() async {
      final entries = await _entries();
      var total = entries.fold<int>(0, (sum, entry) => sum + entry.size);
      if (total <= maxBytes) return;

      entries.sort((a, b) => a.modified.compareTo(b.modified));

      final target = (maxBytes * _trimTo).round();
      for (final entry in entries) {
        if (total <= target) break;
        try {
          await entry.file.delete();
          total -= entry.size;
        } on FileSystemException {
          // Busy or already gone; the next trim will find it.
        }
      }
    });
  }

  Future<List<_CacheEntry>> _entries() async {
    final directory = await this.directory();
    final entries = <_CacheEntry>[];

    try {
      await for (final entity in directory.list()) {
        if (entity is! File) continue;

        final stat = await entity.stat();
        if (stat.type == FileSystemEntityType.notFound) continue;

        entries.add(
          _CacheEntry(file: entity, size: stat.size, modified: stat.modified),
        );
      }
    } on FileSystemException {
      // The directory went away mid-walk — the OS reclaiming its cache, or
      // another process clearing it. What was collected so far still stands.
    }

    return entries;
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.file,
    required this.size,
    required this.modified,
  });

  final File file;
  final int size;
  final DateTime modified;
}

final attachmentFileCacheProvider = Provider<AttachmentFileCache>((ref) {
  return AttachmentFileCache();
});
