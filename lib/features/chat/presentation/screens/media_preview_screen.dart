import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/localization/file_size_format.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/features/chat/data/datasources/photo_compressor.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/message_limits.dart';
import 'package:chatix/features/chat/domain/entities/photo_compression.dart';
import 'package:chatix/features/chat/presentation/providers/local_media_provider.dart';
import 'package:chatix/features/chat/presentation/utils/album_layout.dart';
import 'package:chatix/features/chat/presentation/utils/media_compression_queue.dart';
import 'package:chatix/features/chat/presentation/widgets/album_mosaic.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What the preview screen hands back: what is actually being sent, and the
/// caption that goes with it.
class MediaPreviewResult {
  const MediaPreviewResult({
    required this.uploads,
    this.caption,
    this.asFiles = false,
  });

  final List<AttachmentUploadRequestEntity> uploads;

  /// Becomes the message's `content` (api-docs §5.4) — an album's caption is
  /// the message text, there is no separate field for it.
  final String? caption;

  /// "Send as file": every upload is a `file` attachment, untouched, and —
  /// since a message carries at most one (api-docs §5.5) — each goes in a
  /// message of its own.
  final bool asFiles;
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
/// Three things happen here that cannot happen in the composer: something
/// picked by accident can be dropped, the album gets a caption, and the
/// photos are compressed ([PhotoCompression]) — from the moment the screen
/// opens, a ring on each tile saying how far it has got, so sending is
/// usually instant. Compression can be switched off, and the whole pick can
/// go as files instead. The mosaic is the same [AlbumMosaic] the message
/// will use, measured from the local files — so the preview is the message,
/// not an approximation of it.
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
  final _captionFocus = FocusNode(debugLabel: 'MediaPreview.caption');
  late List<AttachmentUploadRequestEntity> _uploads;
  late final MediaCompressionQueue _compression;

  bool _compress = true;

  /// Send was pressed while photos were still being compressed: the screen
  /// waits for them, and says so on the button.
  bool _waitingToSend = false;

  @override
  void initState() {
    super.initState();
    _uploads = List.of(widget.uploads);
    _caption = TextEditingController(text: widget.initialCaption ?? '')
      ..addListener(_onCaptionChanged);
    _compression = MediaCompressionQueue(ref.read(photoCompressorProvider))
      ..addAll(_uploads);
  }

  @override
  void dispose() {
    _caption.removeListener(_onCaptionChanged);
    _caption.dispose();
    _captionFocus.dispose();
    _compression.dispose();
    super.dispose();
  }

  /// The counter and the send button follow the caption's length.
  void _onCaptionChanged() => setState(() {});

  /// What would go out right now, compressed or not.
  List<AttachmentUploadRequestEntity> get _outgoing => _compress
      ? [for (final upload in _uploads) _compression.resultFor(upload)]
      : _uploads;

  void _remove(int index) {
    _compression.remove(_uploads[index]);
    setState(() => _uploads = [..._uploads]..removeAt(index));

    // Nothing left to send: the screen has become an empty room.
    if (_uploads.isEmpty && mounted) Navigator.of(context).pop();
  }

  String? get _captionToSend {
    final caption = _caption.text.trim();
    return caption.isEmpty ? null : caption;
  }

  Future<void> _send() async {
    if (_uploads.isEmpty || _waitingToSend) return;
    if (MessageLimits.isOverLimit(_caption.text.trim().length)) return;

    if (_compress && _compression.isBusy) {
      setState(() => _waitingToSend = true);
      await _compression.whenDone();
      if (!mounted) return;
    }

    Navigator.of(
      context,
    ).pop(MediaPreviewResult(uploads: _outgoing, caption: _captionToSend));
  }

  /// Every picked file as a document, as it was taken: no compression, the
  /// metadata kept, and each in its own message.
  void _sendAsFiles() {
    if (_uploads.isEmpty) return;
    if (MessageLimits.isOverLimit(_caption.text.trim().length)) return;

    Navigator.of(context).pop(
      MediaPreviewResult(
        uploads: [
          for (final upload in _uploads)
            AttachmentUploadRequestEntity(
              filename: upload.filename,
              mimeType: upload.mimeType,
              fileSize: upload.fileSize,
              filePath: upload.filePath,
              bytes: upload.bytes,
              attachmentType: AttachmentType.file,
            ),
        ],
        caption: _captionToSend,
        asFiles: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canCompress = MediaCompressionQueue.anyApplies(_uploads);

    // Counted as the composer counts, so the two agree about the cap
    // (api-docs §5.4: 4096 for any message content, a caption included).
    final isOverLimit = MessageLimits.isOverLimit(_caption.text.length);

    return ListenableBuilder(
      listenable: _compression,
      builder: (context, _) {
        final totalBytes = _outgoing.fold<int>(
          0,
          (sum, upload) => sum + upload.fileSize,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.attachmentSelection(
                _uploads.length,
                formatFileSize(
                  totalBytes,
                  l10n,
                  locale: Localizations.localeOf(context).toLanguageTag(),
                ),
              ),
            ),
            leading: IconButton(
              tooltip: l10n.cancel,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              PopupMenuButton<VoidCallback>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) => action(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _sendAsFiles,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          size: AppMenuSizes.iconSize,
                        ),
                        const SizedBox(width: AppMenuSizes.iconGap),
                        Text(l10n.mediaPreviewSendAsFile),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppContentWidths.mediaPreview,
                ),
                child: _buildBody(context, l10n, canCompress, isOverLimit),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    bool canCompress,
    bool isOverLimit,
  ) {
    final theme = Theme.of(context);
    final length = _caption.text.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PreviewAlbum(
                  uploads: _uploads,
                  progressOf: (upload) =>
                      _compress ? _compression.progressOf(upload) : null,
                  onRemove: _remove,
                ),
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
        if (canCompress)
          _CompressSwitch(
            value: _compress,
            onChanged: (value) => setState(() => _compress = value),
          ),
        _CaptionBar(
          controller: _caption,
          focusNode: _captionFocus,
          length: length,
          isWaiting: _waitingToSend,
          onSend: _uploads.isEmpty || isOverLimit ? null : _send,
        ),
      ],
    );
  }
}

/// The album's caption and the send button — the composer's own field, so
/// it grows, scrolls and counts the same way.
///
/// One caption per album, because that is all the API has: it becomes the
/// message's `content` (api-docs §5.4), there is no caption per photo. The
/// counter lives inside the field's pill, under the text, so however close
/// to the cap the caption gets the number never slides under the button.
class _CaptionBar extends StatelessWidget {
  const _CaptionBar({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.isWaiting,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool isWaiting;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x3,
        AppSpacing.x1,
        AppSpacing.x3,
        AppSpacing.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: ComposerSizes.fieldMinHeight,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: ComposerField(
                controller: controller,
                focusNode: focusNode,
                enabled: true,
                length: length,
                hintText: l10n.mediaPreviewCaptionHint,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          SizedBox.square(
            dimension: ComposerSizes.fieldMinHeight,
            child: FilledButton(
              onPressed: onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: isWaiting
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Tooltip(
                      message: l10n.composerSendLabel,
                      child: const Icon(Icons.send_rounded, size: 20),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Compress photos", with what that means — or what not doing it means.
class _CompressSwitch extends StatelessWidget {
  const _CompressSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return MergeSemantics(
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        leading: Icon(
          Icons.photo_size_select_large_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(l10n.mediaPreviewCompress),
        subtitle: Text(
          value
              ? l10n.mediaPreviewCompressHint(PhotoCompression.maxSide)
              : l10n.mediaPreviewCompressOffHint,
        ),
        trailing: Switch(value: value, onChanged: onChanged),
        onTap: () => onChanged(!value),
      ),
    );
  }
}

/// The mosaic, with a way off it for each tile.
class _PreviewAlbum extends ConsumerWidget {
  const _PreviewAlbum({
    required this.uploads,
    required this.progressOf,
    required this.onRemove,
  });

  final List<AttachmentUploadRequestEntity> uploads;
  final double? Function(AttachmentUploadRequestEntity upload) progressOf;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratios = [
      for (final upload in uploads)
        ref.watch(localMediaRatioProvider(localMediaKey(upload))).value,
    ];

    // The preview is the one place an album is shown on its own, so it takes
    // the screen's width at the layout's shape — which for a lone photo is
    // the clamped single-photo ratio, there being no height to fit into.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return AlbumMosaic(
          ratios: ratios,
          size: Size(width, width / AlbumLayout.of(ratios).aspectRatio),
          itemBuilder: (context, index) => _PreviewTile(
            upload: uploads[index],
            progress: progressOf(uploads[index]),
            onRemove: () => onRemove(index),
          ),
        );
      },
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.upload,
    required this.progress,
    required this.onRemove,
  });

  final AttachmentUploadRequestEntity upload;

  /// How far this photo's compression has got, or null when it is not being
  /// compressed (any more).
  final double? progress;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isVideo =
        ChatAttachmentLimits.typeOf(upload.mimeType) == AttachmentType.video;
    final progress = this.progress;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Under everything, so a tile is a tile from the first frame —
        // before the photo on the device has finished decoding.
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        if (isVideo)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppPalette.videoGroundTop,
                  AppPalette.videoGroundBottom,
                ],
              ),
            ),
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
        // The photo stays as bright as it will arrive; the ring carries its
        // own ground. One still waiting its turn reads 0 %.
        if (progress != null)
          Center(
            child: TransferProgressRing(
              state: TransferRingState.running,
              progress: progress,
              size: 40,
              semanticLabel: l10n.mediaPreviewCompressing,
            ),
          ),
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
