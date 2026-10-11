import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:chatix/features/chat/data/datasources/photo_compressor.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/photo_compression.dart';

/// A [PhotoCompressor] a test steers: by default every photo comes back at
/// a tenth of its size at once; with [hold] set, each one stops at [holdAt]
/// and waits for [releaseAll].
class FakePhotoCompressor implements PhotoCompressor {
  FakePhotoCompressor({this.hold = false, this.holdAt = 0.4});

  final bool hold;
  final double holdAt;

  final List<AttachmentUploadRequestEntity> seen = [];
  final List<Completer<void>> _held = [];

  static AttachmentUploadRequestEntity compressedOf(
    AttachmentUploadRequestEntity upload,
  ) => AttachmentUploadRequestEntity(
    filename: PhotoCompression.jpegName(upload.filename),
    mimeType: PhotoCompression.outputMimeType,
    fileSize: upload.fileSize ~/ 10,
    filePath: '${upload.filePath}.compressed.jpg',
  );

  @override
  Future<AttachmentUploadRequestEntity?> compress(
    AttachmentUploadRequestEntity upload, {
    ValueChanged<double>? onProgress,
  }) async {
    seen.add(upload);
    if (hold) {
      onProgress?.call(holdAt);
      final gate = Completer<void>();
      _held.add(gate);
      await gate.future;
    }
    onProgress?.call(1);
    return compressedOf(upload);
  }

  void releaseAll() {
    for (final gate in _held) {
      if (!gate.isCompleted) gate.complete();
    }
  }
}
