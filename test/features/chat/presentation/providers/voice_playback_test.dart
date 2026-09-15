import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/voice_playback_provider.dart';

void main() {
  AttachmentEntity attachment({
    required String id,
    AttachmentType type = AttachmentType.voice,
    AttachmentStatus status = AttachmentStatus.success,
    int? duration = 5,
  }) => AttachmentEntity(
    id: id,
    messageId: null,
    chatId: 'chat-1',
    uploaderId: 7,
    attachmentType: type,
    attachmentStatus: status,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/chat-1/$id/voice.ogg',
    mimeType: 'audio/ogg',
    originalFilename: 'voice.ogg',
    size: 2048,
    width: null,
    height: null,
    durationSeconds: duration,
    createdAt: DateTime.utc(2026, 9, 14),
  );

  MessageEntity message(
    String id,
    int seq, {
    List<AttachmentEntity> attachments = const [],
    MessageType type = MessageType.voice,
  }) => MessageEntity(
    id: id,
    chatId: 'chat-1',
    seq: seq,
    authorId: 7,
    type: type,
    content: null,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 9, 14),
    attachments: attachments,
  );

  group('voiceTracksIn', () {
    test('runs oldest first, the way the conversation was said', () {
      // The feed hands them over newest first.
      final tracks = voiceTracksIn([
        message('m3', 3, attachments: [attachment(id: 'a3')]),
        message('m2', 2, attachments: [attachment(id: 'a2')]),
        message('m1', 1, attachments: [attachment(id: 'a1')]),
      ]);

      expect(tracks.map((track) => track.id), ['a1', 'a2', 'a3']);
    });

    test('skips slots the gateway has not finished with', () {
      final tracks = voiceTracksIn([
        message('m2', 2, attachments: [
          attachment(id: 'pending', status: AttachmentStatus.pending),
        ]),
        message('m1', 1, attachments: [
          attachment(id: 'failed', status: AttachmentStatus.error),
        ]),
        message('m0', 0, attachments: [attachment(id: 'ok')]),
      ]);

      expect(tracks.map((track) => track.id), ['ok']);
    });

    test('ignores everything that is not a voice attachment', () {
      final tracks = voiceTracksIn([
        message('m2', 2, type: MessageType.image, attachments: [
          attachment(id: 'photo', type: AttachmentType.image),
        ]),
        message('m1', 1, type: MessageType.videoNote, attachments: [
          attachment(id: 'circle', type: AttachmentType.videoNote),
        ]),
        message('m0', 0, attachments: [attachment(id: 'voice')]),
      ]);

      expect(tracks.map((track) => track.id), ['voice']);
    });

    test('an empty feed queues nothing', () {
      expect(voiceTracksIn(const []), isEmpty);
    });

    test('carries the message a track hangs off, for the download', () {
      final tracks = voiceTracksIn([
        message('m1', 1, attachments: [attachment(id: 'a1')]),
      ]);

      expect(tracks.single.messageId, 'm1');
      expect(tracks.single.chatId, 'chat-1');
    });
  });

  group('VoiceSpeed', () {
    test('cycles 1x, 1.5x, 2x and back', () {
      expect(VoiceSpeed.normal.next, VoiceSpeed.fast);
      expect(VoiceSpeed.fast.next, VoiceSpeed.fastest);
      expect(VoiceSpeed.fastest.next, VoiceSpeed.normal);
    });

    test('reads the way it is written on the button', () {
      expect(VoiceSpeed.normal.label, '1x');
      expect(VoiceSpeed.fast.label, '1.5x');
      expect(VoiceSpeed.fastest.label, '2x');
    });
  });

  group('VoicePlaybackState', () {
    final track = VoiceTrack(
      chatId: 'chat-1',
      messageId: 'm1',
      attachment: attachment(id: 'a1'),
    );

    test('only the loaded track is the current one', () {
      final state = VoicePlaybackState(track: track, isPlaying: true);

      expect(state.isCurrent('a1'), isTrue);
      expect(state.isPlayingNow('a1'), isTrue);
      expect(state.isPlayingNow('a2'), isFalse);
    });

    test('a paused track is current but not playing', () {
      final state = VoicePlaybackState(track: track);
      expect(state.isCurrent('a1'), isTrue);
      expect(state.isPlayingNow('a1'), isFalse);
    });

    test('progress is the fraction played, and safe before anything loads',
        () {
      expect(const VoicePlaybackState().progress, 0);
      expect(
        VoicePlaybackState(
          track: track,
          position: const Duration(seconds: 3),
          duration: const Duration(seconds: 12),
        ).progress,
        0.25,
      );
    });

    test('the declared duration stands in until the file is open', () {
      expect(track.declaredDuration, const Duration(seconds: 5));
      expect(
        VoiceTrack(
          chatId: 'chat-1',
          messageId: 'm1',
          attachment: attachment(id: 'a2', duration: null),
        ).declaredDuration,
        isNull,
      );
    });

    test('what has been heard is remembered by attachment', () {
      const state = VoicePlaybackState(listened: {'a1'});
      expect(state.hasBeenHeard('a1'), isTrue);
      expect(state.hasBeenHeard('a2'), isFalse);
    });
  });
}
