import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/photo_compressor.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/utils/media_compression_queue.dart';

/// Hands each photo back only when the test says so.
class _GatedCompressor implements PhotoCompressor {
  final Map<String, Completer<AttachmentUploadRequestEntity?>> gates = {};
  final Map<String, ValueChanged<double>?> progress = {};
  final List<String> started = [];

  @override
  Future<AttachmentUploadRequestEntity?> compress(
    AttachmentUploadRequestEntity upload, {
    ValueChanged<double>? onProgress,
  }) {
    started.add(upload.filename);
    progress[upload.filename] = onProgress;
    return (gates[upload.filename] = Completer()).future;
  }

  void finish(String name, [AttachmentUploadRequestEntity? result]) =>
      gates[name]!.complete(result);
}

void main() {
  AttachmentUploadRequestEntity photo(
    String name, {
    String mime = 'image/jpeg',
  }) => AttachmentUploadRequestEntity(
    filename: name,
    mimeType: mime,
    fileSize: 4000,
    filePath: '/tmp/$name',
  );

  AttachmentUploadRequestEntity small(String name) =>
      AttachmentUploadRequestEntity(
        filename: name,
        mimeType: 'image/jpeg',
        fileSize: 400,
        filePath: '/tmp/small-$name',
      );

  late _GatedCompressor compressor;
  late MediaCompressionQueue queue;

  setUp(() {
    compressor = _GatedCompressor();
    queue = MediaCompressionQueue(compressor);
  });

  tearDown(() => queue.dispose());

  test('one photo at a time, in order', () async {
    queue.addAll([photo('a.jpg'), photo('b.jpg')]);
    await pumpEventQueue();
    expect(compressor.started, ['a.jpg']);

    compressor.finish('a.jpg', small('a'));
    await pumpEventQueue();
    expect(compressor.started, ['a.jpg', 'b.jpg']);
  });

  test(
    'says how far each photo has got, and nothing once it is done',
    () async {
      final a = photo('a.jpg');
      final b = photo('b.jpg');
      queue.addAll([a, b]);
      await pumpEventQueue();

      compressor.progress['a.jpg']!(0.6);
      expect(queue.progressOf(a), 0.6);
      expect(queue.progressOf(b), 0, reason: 'queued, not started');

      compressor.finish('a.jpg', small('a'));
      await pumpEventQueue();
      expect(queue.progressOf(a), isNull);
    },
  );

  test('sends the compressed copy once there is one', () async {
    final a = photo('a.jpg');
    queue.addAll([a]);
    await pumpEventQueue();
    expect(queue.resultFor(a), a);

    compressor.finish('a.jpg', small('a'));
    await pumpEventQueue();
    expect(queue.resultFor(a).fileSize, 400);
  });

  test('a photo that could not be compressed goes as it is', () async {
    final a = photo('a.jpg');
    queue.addAll([a]);
    await pumpEventQueue();

    compressor.finish('a.jpg');
    await pumpEventQueue();

    expect(queue.resultFor(a), a);
    expect(queue.isBusy, isFalse);
  });

  test('videos and GIFs are left alone', () {
    queue.addAll([
      photo('v.mp4', mime: 'video/mp4'),
      photo('g.gif', mime: 'image/gif'),
    ]);

    expect(queue.isBusy, isFalse);
    expect(compressor.started, isEmpty);
  });

  test('whenDone waits for the last photo', () async {
    queue.addAll([photo('a.jpg'), photo('b.jpg')]);
    var done = false;
    unawaited(queue.whenDone().then((_) => done = true));

    await pumpEventQueue();
    compressor.finish('a.jpg', small('a'));
    await pumpEventQueue();
    expect(done, isFalse);

    compressor.finish('b.jpg', small('b'));
    await pumpEventQueue();
    expect(done, isTrue);
  });

  test('a photo removed before its turn is never compressed', () async {
    final b = photo('b.jpg');
    queue.addAll([photo('a.jpg'), b]);
    await pumpEventQueue();

    queue.remove(b);
    compressor.finish('a.jpg', small('a'));
    await pumpEventQueue();

    expect(compressor.started, ['a.jpg']);
    expect(queue.isBusy, isFalse);
  });

  test(
    'closing the screen mid-way stops the queue and frees a waiter',
    () async {
      final local = MediaCompressionQueue(compressor);
      local.addAll([photo('a.jpg'), photo('b.jpg')]);
      final waiting = local.whenDone();
      await pumpEventQueue();

      local.dispose();
      compressor.finish('a.jpg', small('a'));
      await pumpEventQueue();

      await waiting;
      expect(compressor.started, ['a.jpg']);
    },
  );
}
