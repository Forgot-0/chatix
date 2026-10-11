import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/storage/cache/attachment_file_cache.dart';
import 'package:chatix/features/chat/data/datasources/video_poster_store.dart';
import 'package:chatix/features/chat/domain/entities/video_poster.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';

/// The poster on disk for a video, or null when none has been made yet.
///
/// Re-read when one is made somewhere else — the viewer bringing the file
/// down, a download started from the menu — so a tile that was drawn dark
/// turns into its picture without being scrolled away and back.
final storedVideoPosterProvider = FutureProvider.autoDispose
    .family<File?, AttachmentFileKey>((ref, key) {
      final store = ref.watch(videoPosterStoreProvider);
      final posterKey = VideoPoster.keyOf(key.attachment);

      final subscription = store.made
          .where((made) => made == posterKey)
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(subscription.cancel);

      return store.find(key.attachment);
    });

/// Makes the poster when there is none on disk: from the file already in
/// the cache, or from one the reader's auto-download setting lets the app
/// fetch for it — and only a small one ([VideoPoster.isWorthPrefetching]).
///
/// Null when neither is there to take a frame from; the tile stays dark
/// until the video is opened.
final madeVideoPosterProvider = FutureProvider.autoDispose
    .family<File?, AttachmentFileKey>((ref, key) {
      final store = ref.read(videoPosterStoreProvider);

      final video = VideoPoster.isWorthPrefetching(key.attachment)
          ? ref.watch(autoAttachmentFileProvider(key).future)
          : ref.read(attachmentFileCacheProvider).find(key.attachment.s3Key);

      return video
          .then(
            (file) => file == null ? null : store.ensure(key.attachment, file),
          )
          .catchError((Object _) => null);
    });

/// What a video's tile shows: its poster, or null while there is none.
///
/// The disk is asked first, so a poster already made costs no download; only
/// when it has nothing is one made.
final videoPosterProvider = Provider.autoDispose
    .family<File?, AttachmentFileKey>((ref, key) {
      final stored = ref.watch(storedVideoPosterProvider(key));
      if (!stored.hasValue) return null;

      return stored.value ?? ref.watch(madeVideoPosterProvider(key)).value;
    });

/// The poster of a video picked on this device, for the preview before it
/// is sent.
final localVideoPosterProvider = FutureProvider.autoDispose
    .family<File?, String>(
      (ref, path) => ref.watch(videoPosterStoreProvider).forLocal(path),
    );
