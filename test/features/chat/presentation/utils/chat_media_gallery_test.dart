import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_media_gallery.dart';

void main() {
  const chatId = 'a3f1c2d4-0000-4000-8000-000000000001';

  AttachmentEntity attachment(
    String id, {
    AttachmentType type = AttachmentType.image,
    AttachmentStatus status = AttachmentStatus.success,
  }) => AttachmentEntity(
    id: id,
    messageId: null,
    chatId: chatId,
    uploaderId: 7,
    attachmentType: type,
    attachmentStatus: status,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/$chatId/$id/file',
    mimeType: 'image/jpeg',
    originalFilename: '$id.jpg',
    size: 10,
    width: 100,
    height: 100,
    durationSeconds: null,
    createdAt: DateTime(2026, 3, 1),
  );

  MessageEntity message(
    String id,
    int seq,
    List<AttachmentEntity> attachments,
  ) => MessageEntity(
    id: id,
    chatId: chatId,
    seq: seq,
    authorId: 7,
    type: MessageType.image,
    content: null,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime(2026, 3, 1),
    profile: null,
    attachments: attachments,
    replyTo: null,
    forwardedFrom: null,
  );

  test('runs oldest first, though the feed keeps messages newest first', () {
    final items = ChatMediaGallery.of([
      message('m2', 2, [attachment('b')]),
      message('m1', 1, [attachment('a')]),
    ]);

    expect(items.map((i) => i.attachmentId), ['a', 'b']);
  });

  test('an album keeps its own order inside the message', () {
    final items = ChatMediaGallery.of([
      message('m1', 1, [attachment('a'), attachment('b'), attachment('c')]),
    ]);

    expect(items.map((i) => i.attachmentId), ['a', 'b', 'c']);
  });

  test('videos travel with photos; documents, voice and notes do not', () {
    final items = ChatMediaGallery.of([
      message('m1', 1, [
        attachment('photo'),
        attachment('clip', type: AttachmentType.video),
        attachment('paper', type: AttachmentType.file),
        attachment('note', type: AttachmentType.videoNote),
        attachment('voice', type: AttachmentType.voice),
      ]),
    ]);

    expect(items.map((i) => i.attachmentId), ['photo', 'clip']);
    expect(items.last.isVideo, isTrue);
    expect(items.first.isVideo, isFalse);
  });

  test('slots the gateway has not finished with are left out', () {
    final items = ChatMediaGallery.of([
      message('m1', 1, [
        attachment('ready'),
        attachment('waiting', status: AttachmentStatus.pending),
        attachment('broken', status: AttachmentStatus.error),
      ]),
    ]);

    expect(items.map((i) => i.attachmentId), ['ready']);
  });

  test('each item knows the message it came in, for the header and the '
      'forward', () {
    final items = ChatMediaGallery.of([
      message('m1', 1, [attachment('a')]),
    ]);

    expect(items.single.messageId, 'm1');
    expect(items.single.message.seq, 1);
  });

  test('indexOf finds an attachment, and says so when it cannot', () {
    final items = ChatMediaGallery.of([
      message('m1', 1, [attachment('a'), attachment('b')]),
    ]);

    expect(ChatMediaGallery.indexOf(items, 'b'), 1);
    expect(ChatMediaGallery.indexOf(items, 'gone'), -1);
    expect(ChatMediaGallery.indexOf(const [], 'a'), -1);
  });
}
