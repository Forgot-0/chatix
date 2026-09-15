import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/document_attachment_row.dart';
import 'package:chatix/features/chat/presentation/widgets/message_album.dart';
import 'package:chatix/features/chat/presentation/widgets/video_note_player.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_player.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What a message carries besides its text.
///
/// Photos and videos become an album — a mosaic, not a column, see
/// [MessageAlbum]. A voice message and a video note each get their own
/// player; those two never travel with anything else (api-docs §5.5), so
/// they are always alone here. Documents are a row naming the file.
///
/// Slots the gateway has not confirmed yet say so rather than pretending to
/// be openable, and each kind says it in its own way.
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({
    super.key,
    required this.messageId,
    required this.attachments,
    required this.foreground,
    this.author,
    this.authorId,
    this.isMine = false,
    this.onOpen,
    this.onRetry,
  });

  final String messageId;
  final List<AttachmentEntity> attachments;
  final Color foreground;

  /// Who sent it. Only a voice message draws them — it puts the speaker's
  /// face beside the waveform, the way a voice note is attributed.
  final ChatProfileEntity? author;
  final int? authorId;

  final bool isMine;
  final void Function(AttachmentEntity attachment)? onOpen;

  /// Re-reads the message. The only "try again" an attachment that came back
  /// `attachment_status: error` can be given (api-docs §5.5).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final album = [
      for (final a in attachments)
        if (a.attachmentType == AttachmentType.image ||
            a.attachmentType == AttachmentType.video)
          a,
    ];

    final voice = [
      for (final a in attachments)
        if (a.attachmentType == AttachmentType.voice && _ready(a)) a,
    ];

    final videoNotes = [
      for (final a in attachments)
        if (a.attachmentType == AttachmentType.videoNote && _ready(a)) a,
    ];

    final documents = [
      for (final a in attachments)
        if (a.attachmentType == AttachmentType.file) a,
    ];

    // A voice message or a video note the gateway has not finished with has
    // no player to draw — but it still has to say what became of it, rather
    // than leaving a message that looks empty.
    final stalled = [
      for (final a in attachments)
        if (!_ready(a) &&
            (a.attachmentType == AttachmentType.voice ||
                a.attachmentType == AttachmentType.videoNote))
          a,
    ];

    final accent = ChatixTheme.of(context).success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (album.isNotEmpty)
          MessageAlbum(
            messageId: messageId,
            attachments: album,
            onOpen: onOpen,
            onRetry: onRetry,
          ),
        for (final attachment in voice)
          VoicePlayer(
            attachment: attachment,
            messageId: messageId,
            foreground: foreground,
            accent: accent,
            author: author,
            authorId: authorId,
            isMine: isMine,
          ),
        for (final attachment in videoNotes)
          VideoNotePlayer(attachment: attachment, messageId: messageId),
        for (final attachment in stalled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TransferProgressBadge(
              state: attachment.attachmentStatus == AttachmentStatus.error
                  ? TransferRingState.failed
                  : TransferRingState.waiting,
              progress: 1,
              onPressed: attachment.attachmentStatus == AttachmentStatus.error
                  ? onRetry
                  : null,
              label: attachment.attachmentStatus == AttachmentStatus.error
                  ? AppLocalizations.of(context).attachmentFailed
                  : AppLocalizations.of(context).attachmentProcessing,
            ),
          ),
        for (final attachment in documents)
          DocumentAttachmentRow(
            attachment: attachment,
            messageId: messageId,
            foreground: foreground,
            onRetry: onRetry,
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  static bool _ready(AttachmentEntity attachment) =>
      attachment.attachmentStatus == AttachmentStatus.success;
}
