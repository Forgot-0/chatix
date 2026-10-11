import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/storage/cache/attachment_file_cache.dart';
import 'package:chatix/features/chat/data/datasources/video_frame_extractor.dart';
import 'package:chatix/features/chat/data/datasources/video_poster_store.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/video_poster.dart';

/// Answers with a fixed "JPEG" per path, counting how often it is asked —
/// taking a frame is the expensive part, and what must not be repeated.
class FakeExtractor implements VideoFrameExtractor {
  FakeExtractor({this.frames = const {}});

  final Map<String, List<int>> frames;
  final List<String> asked = [];

  /// When set, every extraction waits for it — to hold one in flight.
  Completer<void>? gate;

  @override
  Future<Uint8List?> firstFrame(
    String path, {
    required int maxWidth,
    required int quality,
  }) async {
    asked.add(path);
    await gate?.future;

    final frame = frames[path];
    return frame == null ? null : Uint8List.fromList(frame);
  }
}

void main() {
  late Directory root;
  late AttachmentFileCache cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('video_poster_store_test');
    cache = AttachmentFileCache(rootDirectory: () async => root);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  AttachmentEntity video(String id, {String? s3Key}) => AttachmentEntity(
    id: id,
    messageId: 'm-$id',
    chatId: 'c1',
    uploaderId: 7,
    attachmentType: AttachmentType.video,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: s3Key ?? 'chats/c1/$id/clip.mp4',
    mimeType: 'video/mp4',
    originalFilename: 'clip.mp4',
    size: 2048,
    width: 1280,
    height: 720,
    durationSeconds: 8,
    createdAt: DateTime(2026, 3, 1),
  );

  Future<File> cachedVideo(AttachmentEntity attachment) =>
      cache.store(attachment.s3Key, [0, 0, 0, 1]);

  test('a video in the cache gets its first frame filed beside it', () async {
    final attachment = video('a');
    final file = await cachedVideo(attachment);
    final extractor = FakeExtractor(
      frames: {
        file.path: [0xFF, 0xD8],
      },
    );
    final store = VideoPosterStore(cache: cache, extractor: extractor);

    final poster = await store.ensure(attachment, file);

    expect(poster, isNotNull);
    expect(await poster!.readAsBytes(), [0xFF, 0xD8]);
    expect(poster.parent.path, file.parent.path);
    expect(
      poster.path,
      endsWith(AttachmentFileCache.posterFileNameFor(attachment.s3Key)),
    );
  });

  test('a poster already on disk is not made again', () async {
    final attachment = video('a');
    final file = await cachedVideo(attachment);
    final extractor = FakeExtractor(
      frames: {
        file.path: [1],
      },
    );

    await VideoPosterStore(
      cache: cache,
      extractor: extractor,
    ).ensure(attachment, file);
    // A new session: nothing in memory, the disk remembers.
    final again = await VideoPosterStore(
      cache: cache,
      extractor: extractor,
    ).ensure(attachment, file);

    expect(again, isNotNull);
    expect(extractor.asked, hasLength(1));
  });

  test('asked twice at once, it takes the frame once', () async {
    final attachment = video('a');
    final file = await cachedVideo(attachment);
    final extractor = FakeExtractor(
      frames: {
        file.path: [1],
      },
    )..gate = Completer<void>();
    final store = VideoPosterStore(cache: cache, extractor: extractor);

    final first = store.ensure(attachment, file);
    final second = store.ensure(attachment, file);
    extractor.gate!.complete();

    expect(await first, isNotNull);
    expect((await second)?.path, (await first)?.path);
    expect(extractor.asked, hasLength(1));
  });

  test('a video the platform cannot read is not asked about again', () async {
    final attachment = video('a');
    final file = await cachedVideo(attachment);
    final extractor = FakeExtractor();
    final store = VideoPosterStore(cache: cache, extractor: extractor);

    expect(await store.ensure(attachment, file), isNull);
    expect(await store.ensure(attachment, file), isNull);
    expect(extractor.asked, hasLength(1));
  });

  test('a tile already on screen hears when its poster is made', () async {
    final attachment = video('a');
    final file = await cachedVideo(attachment);
    final store = VideoPosterStore(
      cache: cache,
      extractor: FakeExtractor(
        frames: {
          file.path: [1],
        },
      ),
    );
    final made = <String>[];
    final subscription = store.made.listen(made.add);
    addTearDown(subscription.cancel);

    await store.ensure(attachment, file);
    await pumpEventQueue();

    expect(made, [VideoPoster.keyOf(attachment)]);
  });

  group('our own videos', () {
    const picked = '/picked/clip.mp4';

    test('get a poster before they are uploaded', () async {
      final extractor = FakeExtractor(
        frames: {
          picked: [7, 7],
        },
      );
      final store = VideoPosterStore(cache: cache, extractor: extractor);

      final poster = await store.forLocal(picked);

      expect(await poster!.readAsBytes(), [7, 7]);
    });

    test(
      'the message shows it the moment it arrives, without a download',
      () async {
        final extractor = FakeExtractor(
          frames: {
            picked: [7, 7],
          },
        );
        final store = VideoPosterStore(cache: cache, extractor: extractor);
        const token = '0b8f0d4e-3a1c-4f55-9a43-6a6c4d7c1a01';

        await store.forLocal(picked);
        await store.adoptUpload(path: picked, uploadToken: token);

        // The message comes back: the attachment's id is the upload token,
        // and only now is its s3_key known.
        final sent = video(token, s3Key: 'chats/c1/uuid4/clip.mp4');
        final found = await store.find(sent);

        expect(await found!.readAsBytes(), [7, 7]);
        expect(
          found.path,
          endsWith(AttachmentFileCache.posterFileNameFor(sent.s3Key)),
        );
        expect(extractor.asked, [picked]);
        // Moved, not copied: the token's copy is gone.
        expect(await cache.findPoster(VideoPoster.uploadKey(token)), isNull);
      },
    );

    test(
      'somebody else\'s video with the same name finds nothing of ours',
      () async {
        final store = VideoPosterStore(
          cache: cache,
          extractor: FakeExtractor(
            frames: {
              picked: [7],
            },
          ),
        );
        await store.adoptUpload(path: picked, uploadToken: 'mine');

        expect(await store.find(video('theirs')), isNull);
      },
    );
  });
}
