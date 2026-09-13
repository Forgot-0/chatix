import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/album_mosaic.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The Hero tag shared by an attachment's tile in the feed and its page in
/// the viewer. Ids are UUIDs, so one tag per attachment is enough.
String attachmentHeroTag(String attachmentId) => 'attachment-$attachmentId';

/// The photos and videos of one message, as a mosaic.
///
/// Several images in a message are an album, not a column: they are laid out
/// by [AlbumMosaic] from the shapes the server measured
/// (`AttachmentDTO.width/height`, api-docs §5.5).
///
/// Each tile also carries the slot's own state. A `pending` attachment is
/// one the gateway has not finished validating; it clears when
/// `attachment_success` names its token — which is the same id the
/// attachment has — so the indicator comes off without refetching anything.
/// An `error` slot says only that it did not work, because that is all the
/// API knows.
class MessageAlbum extends ConsumerWidget {
  const MessageAlbum({
    super.key,
    required this.messageId,
    required this.attachments,
    this.onOpen,
    this.onRetry,
  });

  final String messageId;

  /// Images and videos, in message order.
  final List<AttachmentEntity> attachments;

  final void Function(AttachmentEntity attachment)? onOpen;

  /// Re-reads the message, which is the only "try again" an errored
  /// attachment has (api-docs §5.5 reports no reason and offers no re-run).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final confirmed = ref.watch(confirmedAttachmentTokensProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AlbumMosaic(
        ratios: [for (final a in attachments) _ratioOf(a)],
        itemBuilder: (context, index) {
          final attachment = attachments[index];

          return _AlbumTile(
            attachment: attachment,
            messageId: messageId,
            // A slot the socket has just confirmed is ready even though the
            // copy of the message in hand still says `pending`.
            isReady:
                attachment.attachmentStatus == AttachmentStatus.success ||
                confirmed.contains(attachment.id),
            onOpen: onOpen,
            onRetry: onRetry,
          );
        },
      ),
    );
  }

  static double? _ratioOf(AttachmentEntity attachment) {
    final width = attachment.width;
    final height = attachment.height;
    if (width == null || height == null || height <= 0) return null;
    return width / height;
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.attachment,
    required this.messageId,
    required this.isReady,
    this.onOpen,
    this.onRetry,
  });

  final AttachmentEntity attachment;
  final String messageId;
  final bool isReady;
  final void Function(AttachmentEntity attachment)? onOpen;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (attachment.attachmentStatus == AttachmentStatus.error) {
      return _FailedTile(onRetry: onRetry);
    }

    final content = attachment.attachmentType == AttachmentType.video
        ? _VideoTile(attachment: attachment)
        : DecoratedBox(
            // A ground under the photo, so a tile is a tile from the first
            // frame — a file still being decoded would otherwise leave a
            // hole in the mosaic.
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: AttachmentImage(
              attachment: attachment,
              messageId: messageId,
              borderRadius: BorderRadius.zero,
            ),
          );

    if (!isReady) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const AttachmentImagePlaceholder(),
          Center(
            child: TransferProgressRing(
              state: TransferRingState.waiting,
              semanticLabel: AppLocalizations.of(context).attachmentProcessing,
            ),
          ),
        ],
      );
    }

    // No Hero on a tile that cannot be opened. The context menu shows a
    // second copy of the bubble on a route of its own, and a tag that
    // exists in both would fly the photo into the menu on a long press.
    if (onOpen == null) return content;

    return GestureDetector(
      onTap: () => onOpen!(attachment),
      child: Hero(tag: attachmentHeroTag(attachment.id), child: content),
    );
  }
}

/// A video in an album: no frame to show (the API stores no poster), so a
/// dark tile with the play affordance and, when the server has measured it,
/// how long it runs.
class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.attachment});

  final AttachmentEntity attachment;

  @override
  Widget build(BuildContext context) {
    final seconds = attachment.durationSeconds;

    return ColoredBox(
      color: const Color(0xFF1B1815),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: Icon(
              Icons.play_circle_outline_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          if (seconds != null && seconds > 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formatMediaDuration(Duration(seconds: seconds)),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FailedTile extends StatelessWidget {
  const _FailedTile({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TransferProgressRing(
            state: TransferRingState.failed,
            progress: 1,
            onPressed: onRetry,
            size: 40,
            semanticLabel: l10n.retry,
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              l10n.attachmentFailed,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// `m:ss`, or `h:mm:ss` once a video runs past an hour.
String formatMediaDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes % 60;
  final seconds = value.inSeconds % 60;

  final tail = seconds.toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$tail';

  return '$hours:${minutes.toString().padLeft(2, '0')}:$tail';
}
