import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/video_poster.dart';

void main() {
  AttachmentEntity video({
    String id = '0b8f0d4e-3a1c-4f55-9a43-6a6c4d7c1a01',
    String s3Key = 'chats/c1/0b8f/clip.mp4',
    int size = 4 * 1024 * 1024,
  }) => AttachmentEntity(
    id: id,
    messageId: 'm1',
    chatId: 'c1',
    uploaderId: 7,
    attachmentType: AttachmentType.video,
    attachmentStatus: AttachmentStatus.success,
    // A presigned link that is dead in 300 seconds; never part of a key.
    url: 'https://s3.example/clip.mp4?X-Amz-Signature=abc',
    urlExpiresIn: 300,
    s3Key: s3Key,
    mimeType: 'video/mp4',
    originalFilename: 'clip.mp4',
    size: size,
    width: 1280,
    height: 720,
    durationSeconds: 12,
    createdAt: DateTime(2026, 3, 1),
  );

  group('keys', () {
    test(
      'a downloaded video\'s poster is keyed by its s3_key, not its link',
      () {
        final fresh = video();
        final relinked = AttachmentEntity(
          id: fresh.id,
          messageId: fresh.messageId,
          chatId: fresh.chatId,
          uploaderId: fresh.uploaderId,
          attachmentType: fresh.attachmentType,
          attachmentStatus: fresh.attachmentStatus,
          url: 'https://s3.example/clip.mp4?X-Amz-Signature=def',
          urlExpiresIn: 300,
          s3Key: fresh.s3Key,
          mimeType: fresh.mimeType,
          originalFilename: fresh.originalFilename,
          size: fresh.size,
          width: fresh.width,
          height: fresh.height,
          durationSeconds: fresh.durationSeconds,
          createdAt: fresh.createdAt,
        );

        expect(VideoPoster.keyOf(fresh), 'chats/c1/0b8f/clip.mp4');
        expect(VideoPoster.keyOf(relinked), VideoPoster.keyOf(fresh));
      },
    );

    test('our own video waits under its upload token — the attachment id it '
        'will have', () {
      final attachment = video();

      expect(
        VideoPoster.uploadKey(attachment.id),
        'upload:0b8f0d4e-3a1c-4f55-9a43-6a6c4d7c1a01',
      );
    });

    test('the three kinds of key can never collide', () {
      const path = '/data/user/0/app/cache/picked/clip.mp4';
      const token = '0b8f0d4e-3a1c-4f55-9a43-6a6c4d7c1a01';
      final keys = {
        VideoPoster.keyOf(video()),
        VideoPoster.localKey(path),
        VideoPoster.uploadKey(token),
      };

      expect(keys, hasLength(3));
      // An s3_key starts with `chats/` (api-docs §5.5), never with a scheme.
      expect(VideoPoster.localKey(path), startsWith('local:'));
      expect(VideoPoster.uploadKey(token), startsWith('upload:'));
    });
  });

  group('prefetching for a poster', () {
    test('a small video is worth fetching for its picture', () {
      expect(VideoPoster.isWorthPrefetching(video()), isTrue);
      expect(
        VideoPoster.isWorthPrefetching(
          video(size: VideoPoster.prefetchMaxBytes),
        ),
        isTrue,
      );
    });

    test('a big one waits until it is opened', () {
      expect(
        VideoPoster.isWorthPrefetching(
          video(size: VideoPoster.prefetchMaxBytes + 1),
        ),
        isFalse,
      );
    });

    test('a size the server has not reported is not a reason to fetch', () {
      expect(VideoPoster.isWorthPrefetching(video(size: 0)), isFalse);
    });
  });

  group('which uploads get a poster before they go', () {
    test('a picked video with a file on disk does', () {
      const upload = AttachmentUploadRequestEntity(
        filename: 'clip.mp4',
        mimeType: 'video/mp4',
        fileSize: 1024,
        filePath: '/tmp/clip.mp4',
      );

      expect(VideoPoster.isFor(upload), isTrue);
    });

    test('a photo, a video note, or a video with only bytes does not', () {
      const photo = AttachmentUploadRequestEntity(
        filename: 'a.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024,
        filePath: '/tmp/a.jpg',
      );
      const note = AttachmentUploadRequestEntity.videoNote(
        filename: 'note.mp4',
        mimeType: 'video/mp4',
        fileSize: 1024,
        filePath: '/tmp/note.mp4',
      );
      const inMemory = AttachmentUploadRequestEntity(
        filename: 'clip.mp4',
        mimeType: 'video/mp4',
        fileSize: 3,
        bytes: [1, 2, 3],
      );

      expect(VideoPoster.isFor(photo), isFalse);
      expect(VideoPoster.isFor(note), isFalse);
      expect(VideoPoster.isFor(inMemory), isFalse);
    });
  });
}
