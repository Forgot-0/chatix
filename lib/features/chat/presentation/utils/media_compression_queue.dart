import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:chatix/features/chat/data/datasources/photo_compressor.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/photo_compression.dart';

/// The photos of one album being compressed, one at a time, and how far
/// each has got.
///
/// Started as soon as the preview opens, so by the time a caption is typed
/// the work is usually done. One at a time on purpose: a 50-megapixel photo
/// decoded is 200 MB of pixels, and two of those side by side is how a phone
/// runs out of memory.
class MediaCompressionQueue extends ChangeNotifier {
  MediaCompressionQueue(this._compressor);

  final PhotoCompressor _compressor;

  final List<AttachmentUploadRequestEntity> _waiting = [];
  final Map<AttachmentUploadRequestEntity, double> _progress = {};
  final Map<AttachmentUploadRequestEntity, AttachmentUploadRequestEntity?>
  _results = {};

  bool _running = false;
  bool _disposed = false;
  Completer<void>? _idle;

  /// Queues the photos among [uploads]; videos, GIFs and anything already
  /// queued are passed over.
  void addAll(Iterable<AttachmentUploadRequestEntity> uploads) {
    var added = false;
    for (final upload in uploads) {
      if (!PhotoCompression.appliesTo(upload)) continue;
      if (_progress.containsKey(upload)) continue;
      _waiting.add(upload);
      _progress[upload] = 0;
      added = true;
    }
    if (!added) return;

    _notify();
    unawaited(_drain());
  }

  /// Takes a photo off the album: if it has not started, it never will.
  void remove(AttachmentUploadRequestEntity upload) {
    if (_waiting.remove(upload)) _progress.remove(upload);
  }

  /// How far [upload] has got, 0..1, or null when it is not being worked on
  /// — finished, never queued, or not a photo at all.
  double? progressOf(AttachmentUploadRequestEntity upload) =>
      _results.containsKey(upload) ? null : _progress[upload];

  bool get isBusy => _running || _waiting.isNotEmpty;

  /// What goes out for [upload] when compression is on: the compressed copy
  /// once there is one, and the original otherwise.
  AttachmentUploadRequestEntity resultFor(
    AttachmentUploadRequestEntity upload,
  ) => _results[upload] ?? upload;

  /// Whether any of [uploads] is a photo this would compress.
  static bool anyApplies(Iterable<AttachmentUploadRequestEntity> uploads) =>
      uploads.any(PhotoCompression.appliesTo);

  /// Completes once nothing is waiting or running.
  Future<void> whenDone() {
    if (!isBusy) return Future<void>.value();
    return (_idle ??= Completer<void>()).future;
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;

    while (_waiting.isNotEmpty && !_disposed) {
      final upload = _waiting.removeAt(0);

      final result = await _compressor.compress(
        upload,
        onProgress: (fraction) {
          if (_disposed || !_progress.containsKey(upload)) return;
          _progress[upload] = fraction;
          _notify();
        },
      );
      if (_disposed) break;

      _results[upload] = result;
      _notify();
    }

    _running = false;
    final idle = _idle;
    _idle = null;
    idle?.complete();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _waiting.clear();
    final idle = _idle;
    _idle = null;
    idle?.complete();
    super.dispose();
  }
}
