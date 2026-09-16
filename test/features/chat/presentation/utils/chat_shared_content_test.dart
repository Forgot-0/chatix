import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_shared_content.dart';

/// The shared-content panel is assembled on the device — the API has no
/// media index — so the sorting is the feature, and this is where it is
/// checked.
void main() {
  AttachmentEntity attachment(
    String id, {
    AttachmentType type = AttachmentType.image,
    AttachmentStatus status = AttachmentStatus.success,
  }) => AttachmentEntity(
    id: id,
    messageId: null,
    chatId: 'c',
    uploaderId: 1,
    attachmentType: type,
    attachmentStatus: status,
    url: null,
    urlExpiresIn: null,
    s3Key: 'key/$id',
    mimeType: 'application/octet-stream',
    originalFilename: '$id.bin',
    size: 10,
    width: null,
    height: null,
    durationSeconds: null,
    createdAt: DateTime.utc(2026, 5, 1),
  );

  MessageEntity message(
    int seq, {
    String? content,
    List<AttachmentEntity> attachments = const [],
  }) => MessageEntity(
    id: 'm$seq',
    chatId: 'c',
    seq: seq,
    authorId: 7,
    type: MessageType.text,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 5, 1).add(Duration(minutes: seq)),
    attachments: attachments,
  );

  group('sorting attachments into tabs', () {
    test('each kind lands in its own drawer', () {
      final content = ChatSharedContent.of([
        message(1, attachments: [attachment('a', type: AttachmentType.image)]),
        message(2, attachments: [attachment('b', type: AttachmentType.video)]),
        message(3, attachments: [attachment('c', type: AttachmentType.file)]),
        message(4, attachments: [attachment('d', type: AttachmentType.voice)]),
        message(
          5,
          attachments: [attachment('e', type: AttachmentType.videoNote)],
        ),
      ]);

      expect(
        content.media.map((item) => item.attachmentId),
        // Newest first, so the video note leads and the photo trails.
        ['e', 'b', 'a'],
      );
      expect(content.files.single.attachmentId, 'c');
      expect(content.voice.single.attachmentId, 'd');
    });

    test('an attachment the gateway has not finished with is left out', () {
      final content = ChatSharedContent.of([
        message(
          1,
          attachments: [
            attachment('pending', status: AttachmentStatus.pending),
            attachment('failed', status: AttachmentStatus.error),
            attachment('done'),
          ],
        ),
      ]);

      expect(content.media.map((item) => item.attachmentId), ['done']);
    });

    test('one message with several photos contributes all of them', () {
      final content = ChatSharedContent.of([
        message(1, attachments: [attachment('a'), attachment('b')]),
      ]);

      expect(content.media, hasLength(2));
      expect(content.countOf(SharedContentTab.media), 2);
    });

    test('messages arriving out of order still come back newest first', () {
      final content = ChatSharedContent.of([
        message(2, attachments: [attachment('b')]),
        message(9, attachments: [attachment('i')]),
        message(5, attachments: [attachment('e')]),
      ]);

      expect(content.media.map((item) => item.attachmentId), ['i', 'e', 'b']);
    });

    test('nothing shared is four empty tabs, not a null', () {
      final content = ChatSharedContent.of([message(1, content: 'hello')]);

      expect(content.isEmpty, isTrue);
      for (final tab in SharedContentTab.values) {
        expect(content.countOf(tab), 0);
      }
    });
  });

  group('links', () {
    test('a web address in the text becomes a link, with its scheme', () {
      final content = ChatSharedContent.of([
        message(1, content: 'read www.example.com/docs today'),
      ]);

      expect(content.links.single.label, 'www.example.com/docs');
      expect(content.links.single.target, 'https://www.example.com/docs');
    });

    test('the same address twice in one message is listed once', () {
      final content = ChatSharedContent.of([
        message(1, content: 'https://a.test and again https://a.test'),
      ]);

      expect(content.links, hasLength(1));
    });

    test('an email or a mention is not a link anyone goes looking for', () {
      final content = ChatSharedContent.of([
        message(1, content: 'ask me@example.com or @ann about it'),
      ]);

      expect(content.links, isEmpty);
    });

    test('links keep the message they were written in', () {
      final content = ChatSharedContent.of([
        message(4, content: 'see https://a.test'),
      ]);

      expect(content.links.single.messageId, 'm4');
    });
  });

  group('merging the feed with the cache', () {
    test('the feed wins where both hold the same message', () {
      final live = [message(1, content: 'edited')];
      final cached = [message(1, content: 'stale')];

      final merged = mergeSharedContentSources(live, cached);

      expect(merged, hasLength(1));
      expect(merged.single.content, 'edited');
    });

    test('the cache adds what the feed has not loaded', () {
      final merged = mergeSharedContentSources(
        [message(3)],
        [message(1), message(2)],
      );

      expect(merged.map((m) => m.seq), [3, 2, 1]);
    });

    test('two empty sources are an empty list, not a crash', () {
      expect(mergeSharedContentSources(const [], const []), isEmpty);
    });
  });
}
