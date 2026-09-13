import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/message_limits.dart';
import 'package:chatix/features/chat/presentation/providers/local_media_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/album_mosaic.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What the preview screen hands back: what is actually being sent, and the
/// caption that goes with it.
class MediaPreviewResult {
  const MediaPreviewResult({required this.uploads, this.caption});

  final List<AttachmentUploadRequestEntity> uploads;

  /// Becomes the message's `content` (api-docs §5.4) — an album's caption is
  /// the message text, there is no separate field for it.
  final String? caption;
}

/// Everything the preview screen needs, as one object, because it travels
/// through the router's `extra`.
class MediaPreviewArgs {
  const MediaPreviewArgs({required this.uploads, this.caption});

  final List<AttachmentUploadRequestEntity> uploads;
  final String? caption;
}

/// What was picked, laid out as it will arrive, before it is sent.
///
/// Two things happen here that cannot happen in the composer: something
/// picked by accident can be dropped, and the album gets a caption. The
/// mosaic is the same [AlbumMosaic] the message will use, measured from the
/// local files — so the preview is the message, not an approximation of it.
class MediaPreviewScreen extends ConsumerStatefulWidget {
  const MediaPreviewScreen({
    super.key,
    required this.chatId,
    required this.uploads,
    this.initialCaption,
  });

  final String chatId;
  final List<AttachmentUploadRequestEntity> uploads;
  final String? initialCaption;

  @override
  ConsumerState<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends ConsumerState<MediaPreviewScreen> {
  late final TextEditingController _caption;
  late List<AttachmentUploadRequestEntity> _uploads;

  @override
  void initState() {
    super.initState();
    _uploads = List.of(widget.uploads);
    _caption = TextEditingController(text: widget.initialCaption ?? '');
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _remove(int index) {
    setState(() => _uploads = [..._uploads]..removeAt(index));

    // Nothing left to send: the screen has become an empty room.
    if (_uploads.isEmpty && mounted) Navigator.of(context).pop();
  }

  void _send() {
    if (_uploads.isEmpty) return;

    final caption = _caption.text.trim();
    if (MessageLimits.isOverLimit(caption.length)) return;

    Navigator.of(context).pop(
      MediaPreviewResult(
        uploads: _uploads,
        caption: caption.isEmpty ? null : caption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final totalBytes = _uploads.fold<int>(
      0,
      (sum, upload) => sum + upload.fileSize,
    );

    final length = _caption.text.characters.length;
    final isOverLimit = MessageLimits.isOverLimit(length);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.attachmentSelection(
            _uploads.length,
            ChatAttachmentLimits.formatBytes(totalBytes),
          ),
        ),
        leading: IconButton(
          tooltip: l10n.cancel,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PreviewAlbum(uploads: _uploads, onRemove: _remove),
                    const SizedBox(height: AppSpacing.x3),
                    Text(
                      l10n.mediaPreviewHint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x3,
                0,
                AppSpacing.x3,
                AppSpacing.x3,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          MessageLimits.maxContentLength,
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText: l10n.mediaPreviewCaptionHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        counterText: MessageLimits.showsCounter(length)
                            ? '${MessageLimits.remaining(length)}'
                            : '',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  FilledButton(
                    onPressed: _uploads.isEmpty || isOverLimit ? null : _send,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(AppSpacing.x3),
                    ),
                    child: const Icon(Icons.send_rounded, size: 20),
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

/// The mosaic, with a way off it for each tile.
class _PreviewAlbum extends ConsumerWidget {
  const _PreviewAlbum({required this.uploads, required this.onRemove});

  final List<AttachmentUploadRequestEntity> uploads;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratios = [
      for (final upload in uploads)
        ref.watch(localMediaRatioProvider(localMediaKey(upload))).value,
    ];

    return AlbumMosaic(
      ratios: ratios,
      itemBuilder: (context, index) => _PreviewTile(
        upload: uploads[index],
        onRemove: () => onRemove(index),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.upload, required this.onRemove});

  final AttachmentUploadRequestEntity upload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isVideo =
        ChatAttachmentLimits.typeOf(upload.mimeType) == AttachmentType.video;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Under everything, so a tile is a tile from the first frame —
        // before the photo on the device has finished decoding.
        ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
        if (isVideo)
          const ColoredBox(
            color: Color(0xFF1B1815),
            child: Center(
              child: Icon(
                Icons.movie_creation_outlined,
                color: Colors.white70,
                size: 32,
              ),
            ),
          )
        else
          _LocalImage(upload: upload),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkResponse(
              onTap: onRemove,
              radius: 18,
              child: Tooltip(
                message: l10n.mediaPreviewRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A picked image straight off the device — no cache, no network; it has not
/// been anywhere yet.
class _LocalImage extends StatelessWidget {
  const _LocalImage({required this.upload});

  final AttachmentUploadRequestEntity upload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final path = upload.filePath;
    if (path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _blank(scheme),
      );
    }

    final bytes = upload.bytes;
    if (bytes != null) {
      return Image.memory(
        Uint8List.fromList(bytes),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _blank(scheme),
      );
    }

    return _blank(scheme);
  }

  Widget _blank(ColorScheme scheme) => ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Icon(Icons.image_outlined, color: scheme.outline),
  );
}
