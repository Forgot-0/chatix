import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/storage/cache/attachment_file_cache.dart';

/// How much disk the attachment cache is actually holding, in bytes.
///
/// Measured rather than tracked: the cache directory is one the OS may empty
/// on its own, so a running total kept in preferences would drift and then
/// lie to the reader about what pressing "clear" is going to free. Walking
/// the directory is cheap enough to do when the settings screen opens.
///
/// Re-reads whenever the limit changes — a lower limit evicts, and the
/// number on screen should show it.
final attachmentCacheUsageProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  return ref.watch(attachmentFileCacheProvider).usedBytes();
});

/// Empties the attachment cache and republishes the measurement.
///
/// Answers with the number of bytes that were freed, so the caller can say
/// what it did rather than just that it did something.
final clearAttachmentCacheProvider = Provider<Future<int> Function()>((ref) {
  return () async {
    final cache = ref.read(attachmentFileCacheProvider);
    final before = await cache.usedBytes();
    await cache.clear();
    ref.invalidate(attachmentCacheUsageProvider);
    return before;
  };
});
