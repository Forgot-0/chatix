import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/storage/cache/attachment_file_cache.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/video_frame_extractor.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/video_poster.dart';

/// Makes, files and finds video posters (see [VideoPoster]).
///
/// The JPEGs go into the attachment cache next to the videos they came
/// from, so they share its eviction budget and are found by `s3_key` alone.
/// Nothing here throws: a missing poster is the ordinary case — a desktop,
/// a file still coming down — and the tile simply keeps its dark ground.
class VideoPosterStore {
  VideoPosterStore({
    required AttachmentFileCache cache,
    required VideoFrameExtractor extractor,
  }) : _cache = cache,
       _extractor = extractor;

  final AttachmentFileCache _cache;
  final VideoFrameExtractor _extractor;

  /// One attempt per key at a time: a tile, the viewer and the download
  /// that just landed all ask for the same poster within the same second.
  final Map<String, Future<File?>> _making = {};

  /// Keys this session has already failed to take a frame from. A file the
  /// platform cannot read does not become readable by being asked again on
  /// every scroll past it.
  final Set<String> _failed = {};

  final StreamController<String> _made = StreamController<String>.broadcast();

  /// The keys of posters as they are made, so a tile drawn before its
  /// poster existed can pick it up without anything being reloaded.
  Stream<String> get made => _made.stream;

  /// The poster on disk for [attachment], or null when there is none yet.
  ///
  /// For a video of our own that is the one made before it was uploaded,
  /// waiting under the upload token — which is this attachment's id — and
  /// moved under the `s3_key` here, the first time the attachment is seen.
  Future<File?> find(AttachmentEntity attachment) async {
    final key = VideoPoster.keyOf(attachment);

    try {
      final own = await _cache.findPoster(key);
      if (own != null) return own;

      final uploaded = await _cache.findPoster(
        VideoPoster.uploadKey(attachment.id),
      );
      if (uploaded == null) return null;

      final moved = await _cache.storePoster(key, await uploaded.readAsBytes());
      await _deleteQuietly(uploaded);
      return moved;
    } on Object catch (error) {
      Logger.warning('Video poster: could not look up $key ($error)');
      return null;
    }
  }

  /// The poster of [attachment], made from its [video] file — already in
  /// the cache — unless there is one on disk already.
  Future<File?> ensure(AttachmentEntity attachment, File video) {
    final key = VideoPoster.keyOf(attachment);

    return _once(
      key,
      () async => await find(attachment) ?? await _make(key, video.path),
    );
  }

  /// A poster for the video at [path] on this device, made before it is
  /// uploaded: the preview shows it, and [adoptUpload] hands it on to the
  /// message.
  Future<File?> forLocal(String path) {
    final key = VideoPoster.localKey(path);

    return _once(
      key,
      () async => await _cache.findPoster(key) ?? await _make(key, path),
    );
  }

  /// Files the poster of the picked file at [path] under the upload slot it
  /// went out in, so the message's tile has its frame the moment the
  /// message arrives — before anyone has downloaded a byte of it.
  Future<void> adoptUpload({
    required String path,
    required String uploadToken,
  }) async {
    try {
      final poster = await forLocal(path);
      if (poster == null) return;

      await _cache.storePoster(
        VideoPoster.uploadKey(uploadToken),
        await poster.readAsBytes(),
      );
    } on Object catch (error) {
      Logger.warning('Video poster: could not keep $path for upload ($error)');
    }
  }

  Future<File?> _make(String key, String path) async {
    final bytes = await _extractor.firstFrame(
      path,
      maxWidth: VideoPoster.maxWidth,
      quality: VideoPoster.quality,
    );
    if (bytes == null) {
      _failed.add(key);
      return null;
    }

    final file = await _cache.storePoster(key, bytes);
    if (!_made.isClosed) _made.add(key);
    return file;
  }

  Future<File?> _once(String key, Future<File?> Function() run) {
    if (_failed.contains(key)) return Future.value();

    final running = _making[key];
    if (running != null) return running;

    late final Future<File?> attempt;
    attempt = run()
        .catchError((Object error) {
          Logger.warning('Video poster: $key could not be made ($error)');
          return null;
        })
        .whenComplete(() {
          if (identical(_making[key], attempt)) _making.remove(key);
        });

    _making[key] = attempt;
    return attempt;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone, or busy: eviction will get to it.
    }
  }

  void dispose() => _made.close();
}

final videoPosterStoreProvider = Provider<VideoPosterStore>((ref) {
  final store = VideoPosterStore(
    cache: ref.watch(attachmentFileCacheProvider),
    extractor: ref.watch(videoFrameExtractorProvider),
  );
  ref.onDispose(store.dispose);
  return store;
});
