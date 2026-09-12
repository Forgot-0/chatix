import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/video_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_player.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What a message carries besides its text.
///
/// Images go into a grid, anything playable gets its own player, and the rest
/// become rows naming the file. A slot the gateway has not confirmed yet
/// (`attachment_success`, api-docs §5.5) says so rather than pretending to be
/// openable.
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({
    super.key,
    required this.messageId,
    required this.attachments,
    required this.foreground,
    this.onOpen,
  });

  final String messageId;
  final List<AttachmentEntity> attachments;
  final Color foreground;
  final void Function(AttachmentEntity attachment)? onOpen;

  @override
  Widget build(BuildContext context) {
    bool ready(AttachmentEntity a) =>
        a.attachmentStatus == AttachmentStatus.success;

    final images = [
      for (final a in attachments)
        if (a.attachmentType == AttachmentType.image && ready(a)) a,
    ];
    final playable = [
      for (final a in attachments)
        if (ready(a) &&
            (a.attachmentType == AttachmentType.video ||
                a.attachmentType == AttachmentType.videoNote ||
                a.attachmentType == AttachmentType.voice))
          a,
    ];
    final rest = [
      for (final a in attachments)
        if (!images.contains(a) && !playable.contains(a)) a,
    ];

    final accent = ChatixTheme.of(context).success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          _AttachmentImageGrid(messageId: messageId, images: images, onOpen: onOpen),
        for (final attachment in playable)
          switch (attachment.attachmentType) {
            AttachmentType.voice => VoicePlayer(
              attachment: attachment,
              messageId: messageId,
              foreground: foreground,
              accent: accent,
            ),
            AttachmentType.videoNote => VideoPreview(
              attachment: attachment,
              messageId: messageId,
              isCircular: true,
            ),
            _ => GestureDetector(
              onTap: () => onOpen?.call(attachment),
              child: VideoPreview(attachment: attachment, messageId: messageId),
            ),
          },
        for (final attachment in rest)
          _AttachmentFileRow(
            attachment: attachment,
            onOpen: onOpen,
            foreground: foreground,
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _AttachmentImageGrid extends StatelessWidget {
  const _AttachmentImageGrid({
    required this.messageId,
    required this.images,
    this.onOpen,
  });

  final String messageId;
  final List<AttachmentEntity> images;
  final void Function(AttachmentEntity attachment)? onOpen;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      final only = images.first;
      final ratio =
          (only.width != null && only.height != null && only.height! > 0)
          ? (only.width! / only.height!).clamp(0.6, 1.8)
          : 1.4;

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () => onOpen?.call(only),
          child: AspectRatio(
            aspectRatio: ratio.toDouble(),
            child: AttachmentImage(attachment: only, messageId: messageId),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: images.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemBuilder: (context, index) {
          final attachment = images[index];
          return GestureDetector(
            onTap: () => onOpen?.call(attachment),
            child: AttachmentImage(
              attachment: attachment,
              messageId: messageId,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }
}

class _AttachmentFileRow extends StatelessWidget {
  const _AttachmentFileRow({
    required this.attachment,
    required this.foreground,
    this.onOpen,
  });

  final AttachmentEntity attachment;
  final Color foreground;
  final void Function(AttachmentEntity attachment)? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final l10n = AppLocalizations.of(context);

    final (icon, label) = switch (attachment.attachmentStatus) {
      AttachmentStatus.pending => (
        Icons.hourglass_empty,
        l10n.attachmentProcessing,
      ),
      AttachmentStatus.error => (Icons.error_outline, l10n.attachmentFailed),
      AttachmentStatus.success => (
        switch (attachment.attachmentType) {
          AttachmentType.image => Icons.image_outlined,
          AttachmentType.video => Icons.videocam_outlined,
          AttachmentType.file => Icons.attach_file,
          AttachmentType.voice => Icons.mic_outlined,
          AttachmentType.videoNote => Icons.videocam_rounded,
        },
        ChatAttachmentLimits.formatBytes(attachment.size),
      ),
    };

    return InkWell(
      onTap: attachment.attachmentStatus == AttachmentStatus.success
          ? () => onOpen?.call(attachment)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.originalFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          attachment.attachmentStatus == AttachmentStatus.error
                          ? ChatixTheme.of(context).danger
                          : foreground.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

