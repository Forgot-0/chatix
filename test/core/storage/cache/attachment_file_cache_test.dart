import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/storage/cache/attachment_file_cache.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('attachment_cache_test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  AttachmentFileCache cacheOf({int maxBytes = AttachmentFileCache.defaultMaxBytes}) =>
      AttachmentFileCache(
        rootDirectory: () async => root,
        maxBytes: maxBytes,
      );

  const key = 'chats/6f1/9c2e/holiday.jpg';

  group('naming', () {
    test('the same key always names the same file', () {
      expect(
        AttachmentFileCache.fileNameFor(key),
        AttachmentFileCache.fileNameFor(key),
      );
    });

    test('different keys name different files', () {
      expect(
        AttachmentFileCache.fileNameFor(key),
        isNot(AttachmentFileCache.fileNameFor('chats/6f1/9c2e/holiday2.jpg')),
      );
    });

    test('the extension is kept so the platform can tell what it is', () {
      expect(AttachmentFileCache.fileNameFor(key), endsWith('.jpg'));
    });

    test('a key with no usable extension is still a legal filename', () {
      final name = AttachmentFileCache.fileNameFor('chats/6f1/9c2e/report');

      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('.')));
      expect(name, isNotEmpty);
    });

    test('a key that is all path separators cannot escape the directory', () {
      final name = AttachmentFileCache.fileNameFor('../../etc/passwd');

      expect(name, isNot(contains('/')));
      expect(name, isNot(startsWith('.')));
    });
  });

  group('poster naming', () {
    const video = 'chats/6f1/9c2e/clip.mp4';

    test('the poster of a video is named by its key, so the same video always '
        'finds the same poster — whatever link it came down through', () {
      expect(
        AttachmentFileCache.posterFileNameFor(video),
        AttachmentFileCache.posterFileNameFor(video),
      );
      expect(
        AttachmentFileCache.posterFileNameFor(video),
        isNot(
          AttachmentFileCache.posterFileNameFor('chats/6f1/9c2e/clip2.mp4'),
        ),
      );
    });

    test('it sits beside the video: same hash, poster suffix', () {
      final videoName = AttachmentFileCache.fileNameFor(video);
      final posterName = AttachmentFileCache.posterFileNameFor(video);

      expect(videoName, endsWith('.mp4'));
      expect(posterName, endsWith(AttachmentFileCache.posterSuffix));
      expect(
        posterName.substring(0, posterName.indexOf('.')),
        videoName.substring(0, videoName.indexOf('.')),
      );
    });

    test('it is always a JPEG, whatever the container', () {
      for (final key in [
        'chats/a/b/clip.mov',
        'chats/a/b/clip.webm',
        'chats/a/b/clip',
      ]) {
        expect(AttachmentFileCache.posterFileNameFor(key), endsWith('.jpg'));
      }
    });

    test('a poster can never be taken for a cached file', () {
      // A cached file's name has at most one dot; a poster's has two.
      for (final key in [video, 'chats/a/b/poster.jpg', 'chats/a/b/x']) {
        expect(
          AttachmentFileCache.posterFileNameFor(key),
          isNot(AttachmentFileCache.fileNameFor(key)),
        );
        expect(
          '.'.allMatches(AttachmentFileCache.fileNameFor(key)).length,
          lessThanOrEqualTo(1),
        );
      }
    });

    test('a hostile key still makes a legal name in the directory', () {
      final name = AttachmentFileCache.posterFileNameFor('../../etc/passwd');

      expect(name, isNot(contains('/')));
      expect(name, isNot(startsWith('.')));
    });
  });

  group('posters on disk', () {
    const video = 'chats/6f1/9c2e/clip.mp4';

    test('a poster that was never made is a miss', () async {
      expect(await cacheOf().findPoster(video), isNull);
    });

    test(
      'a stored poster comes back, beside the video and apart from it',
      () async {
        final cache = cacheOf();
        final file = await cache.store(video, [1, 2, 3]);
        final poster = await cache.storePoster(video, [9, 9]);

        expect(poster.parent.path, file.parent.path);
        expect(await (await cache.findPoster(video))!.readAsBytes(), [9, 9]);
        expect(await (await cache.find(video))!.readAsBytes(), [1, 2, 3]);
      },
    );

    test('clearing the cache takes the posters too', () async {
      final cache = cacheOf();
      await cache.storePoster(video, [9]);

      await cache.clear();

      expect(await cache.findPoster(video), isNull);
    });
  });

  group('storing and finding', () {
    test('a key that was never stored is a miss', () async {
      expect(await cacheOf().find(key), isNull);
    });

    test('what was stored comes back with the same bytes', () async {
      final cache = cacheOf();
      await cache.store(key, [1, 2, 3, 4]);

      final found = await cache.find(key);

      expect(found, isNotNull);
      expect(await found!.readAsBytes(), [1, 2, 3, 4]);
    });

    test('a second cache over the same directory finds the first one\'s '
        'files — the key, not the link, is what identifies them', () async {
      await cacheOf().store(key, [7, 7, 7]);

      final found = await cacheOf().find(key);

      expect(found, isNotNull);
      expect(await found!.readAsBytes(), [7, 7, 7]);
    });

    test('storing again replaces the file rather than appending', () async {
      final cache = cacheOf();
      await cache.store(key, [1, 2, 3, 4, 5]);
      await cache.store(key, [9]);

      final found = await cache.find(key);

      expect(await found!.readAsBytes(), [9]);
    });

    test('no half-written file is left behind to read as a hit', () async {
      final cache = cacheOf();
      await cache.store(key, [1, 2, 3]);

      final directory = await cache.directory();
      final leftovers = directory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.part'),
      );

      expect(leftovers, isEmpty);
    });
  });

  group('eviction', () {
    test('stays under the cap by dropping the oldest first', () async {
      // Room for about four of these.
      final cache = cacheOf(maxBytes: 400);

      for (var i = 0; i < 8; i++) {
        await cache.store('chats/c/$i/photo$i.jpg', List<int>.filled(100, i));
        // Distinct timestamps, so "oldest" means something on filesystems
        // with a coarse clock.
        await Future<void>.delayed(const Duration(milliseconds: 12));
      }

      // Trimming runs in the background behind `store`.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(await cache.usedBytes(), lessThanOrEqualTo(400));
      expect(await cache.find('chats/c/7/photo7.jpg'), isNotNull);
      expect(await cache.find('chats/c/0/photo0.jpg'), isNull);
    });

    test('clear empties the directory', () async {
      final cache = cacheOf();
      await cache.store(key, [1, 2, 3]);

      await cache.clear();

      expect(await cache.find(key), isNull);
      expect(await cache.usedBytes(), 0);
    });
  });
}
