import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_preview.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  const me = 7;
  const peer = 9;

  AttachmentEntity attachment({
    required AttachmentType type,
    String filename = 'file.bin',
    int? duration,
  }) => AttachmentEntity(
    id: 'att',
    messageId: 'm1',
    chatId: 'c1',
    uploaderId: peer,
    attachmentType: type,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: 'key',
    mimeType: 'application/octet-stream',
    originalFilename: filename,
    size: 10,
    width: null,
    height: null,
    durationSeconds: duration,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  MessageEntity message({
    String? content,
    MessageType type = MessageType.text,
    int authorId = peer,
    List<AttachmentEntity> attachments = const [],
  }) => MessageEntity(
    id: 'm1',
    chatId: 'c1',
    seq: 4,
    authorId: authorId,
    type: type,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 1, 1),
    attachments: attachments,
    profile: ChatProfileEntity(
      userId: authorId,
      username: 'ann',
      displayName: authorId == me ? 'Me' : 'Ann',
      avatarUrl: null,
      avatarS3Key: null,
    ),
  );

  ChatEntity chat({
    ChatType type = ChatType.group,
    MessageEntity? last,
    String? description,
  }) => ChatEntity(
    id: 'c1',
    seqCounter: 4,
    lastActivityAt: DateTime.utc(2026, 1, 1),
    type: type,
    name: 'Chat',
    description: description,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 3,
    unreadCount: 0,
    lastMessage: last,
  );

  group('chatPreviewOf', () {
    test('a draft outranks whatever the chat itself last said', () {
      final preview = chatPreviewOf(
        chat(last: message(content: 'hello there')),
        l10n,
        draft: '  see you  ',
        myUserId: me,
      );

      expect(preview.isDraft, isTrue);
      expect(preview.body, 'see you');
      expect(preview.author, isNull);
    });

    test('blank draft text is not a draft', () {
      final preview = chatPreviewOf(
        chat(last: message(content: 'hello')),
        l10n,
        draft: '   ',
        myUserId: me,
      );

      expect(preview.isDraft, isFalse);
      expect(preview.body, 'hello');
    });

    test('a group names the author, a direct chat does not', () {
      final group = chatPreviewOf(
        chat(last: message(content: 'hi')),
        l10n,
        myUserId: me,
      );
      final direct = chatPreviewOf(
        chat(type: ChatType.direct, last: message(content: 'hi')),
        l10n,
        myUserId: me,
      );

      expect(group.author, 'Ann');
      expect(direct.author, isNull);
    });

    test('your own message in a group is credited to you', () {
      final preview = chatPreviewOf(
        chat(last: message(content: 'hi', authorId: me)),
        l10n,
        myUserId: me,
      );

      expect(preview.author, l10n.previewYou);
    });

    test('a channel speaks with one voice, so it credits nobody', () {
      final preview = chatPreviewOf(
        chat(type: ChatType.channel, last: message(content: 'Build 4.2 is out')),
        l10n,
        myUserId: me,
      );

      expect(preview.author, isNull);
      expect(preview.body, 'Build 4.2 is out');
    });

    test('a system message is credited to nobody', () {
      final preview = chatPreviewOf(
        chat(last: message(content: 'Ann joined', type: MessageType.system)),
        l10n,
        myUserId: me,
      );

      expect(preview.author, isNull);
      expect(preview.body, 'Ann joined');
    });

    test('newlines are folded so the row stays one line', () {
      final preview = chatPreviewOf(
        chat(last: message(content: 'first\n\nsecond')),
        l10n,
        myUserId: me,
      );

      expect(preview.body, 'first second');
    });

    test('an uncaptioned photo reads as its kind, with a glyph', () {
      final preview = chatPreviewOf(
        chat(
          last: message(
            type: MessageType.image,
            attachments: [attachment(type: AttachmentType.image)],
          ),
        ),
        l10n,
        myUserId: me,
      );

      expect(preview.body, l10n.previewPhoto);
      expect(preview.icon, isNotNull);
    });

    test('a voice message carries its length', () {
      final preview = chatPreviewOf(
        chat(
          last: message(
            type: MessageType.voice,
            attachments: [
              attachment(type: AttachmentType.voice, duration: 14),
            ],
          ),
        ),
        l10n,
        myUserId: me,
      );

      expect(preview.body, l10n.previewVoiceWithDuration('0:14'));
    });

    test('a voice message of unknown length just says what it is', () {
      final preview = chatPreviewOf(
        chat(last: message(type: MessageType.voice)),
        l10n,
        myUserId: me,
      );

      expect(preview.body, l10n.previewVoice);
    });

    test('a document is named by its filename', () {
      final preview = chatPreviewOf(
        chat(
          last: message(
            type: MessageType.file,
            attachments: [
              attachment(type: AttachmentType.file, filename: 'report.pdf'),
            ],
          ),
        ),
        l10n,
        myUserId: me,
      );

      expect(preview.body, 'report.pdf');
    });

    test('a caption wins over the kind but keeps the glyph', () {
      final preview = chatPreviewOf(
        chat(
          last: message(
            content: 'look at this',
            type: MessageType.image,
            attachments: [attachment(type: AttachmentType.image)],
          ),
        ),
        l10n,
        myUserId: me,
      );

      expect(preview.body, 'look at this');
      expect(preview.icon, isNotNull);
    });

    test('a chat with no messages falls back to its description', () {
      final preview = chatPreviewOf(
        chat(description: 'Release planning'),
        l10n,
        myUserId: me,
      );

      expect(preview.body, 'Release planning');
      expect(preview.isPlaceholder, isTrue);
    });

    test('a chat with neither says so', () {
      final preview = chatPreviewOf(chat(), l10n, myUserId: me);

      expect(preview.body, l10n.noMessagesYet);
      expect(preview.isPlaceholder, isTrue);
    });
  });

  group('formatVoiceDuration', () {
    test('pads seconds and grows an hours field only when needed', () {
      expect(formatVoiceDuration(0), '0:00');
      expect(formatVoiceDuration(14), '0:14');
      expect(formatVoiceDuration(605), '10:05');
      expect(formatVoiceDuration(3725), '1:02:05');
    });
  });
}
