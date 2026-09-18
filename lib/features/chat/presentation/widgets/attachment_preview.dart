import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// An image attachment, drawn from the file cache.
///
/// Never from `AttachmentDTO.url` directly: that link is dead 300 seconds
/// after it was minted (api-docs §5.5), so what is cached is the file under
/// its `s3_key` and the link is re-requested behind the scenes whenever it
/// has gone stale. From here that is invisible — there is a file, or there
/// is a failure with a way to try again.
class AttachmentImage extends ConsumerStatefulWidget {
  const AttachmentImage({
    super.key,
    required this.attachment,
    required this.messageId,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final AttachmentEntity attachment;
  final String messageId;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  ConsumerState<AttachmentImage> createState() => _AttachmentImageState();
}

class _AttachmentImageState extends ConsumerState<AttachmentImage> {
  /// Set once the reader has tapped a picture their settings were holding
  /// back. From then on this image is fetched like any other — the setting
  /// is about what happens without being asked, not about what may be
  /// downloaded at all.
  bool _asked = false;

  AttachmentFileKey get _key =>
      attachmentFileKey(widget.attachment, messageId: widget.messageId);

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);

    return ClipRRect(borderRadius: radius, child: _body());
  }

  Widget _body() {
    if (_asked) {
      return ref
          .watch(attachmentFileProvider(_key))
          .when(
            loading: () => const AttachmentImagePlaceholder(),
            error: (_, _) => AttachmentImageFailure(
              onRetry: () => ref.invalidate(attachmentFileProvider(_key)),
            ),
            data: _image,
          );
    }

    return ref
        .watch(autoAttachmentFileProvider(_key))
        .when(
          loading: () => const AttachmentImagePlaceholder(),
          error: (_, _) => AttachmentImageFailure(
            onRetry: () => ref.invalidate(autoAttachmentFileProvider(_key)),
          ),
          // Null is the settings answer: not on this connection, not before
          // you ask. So ask.
          data: (file) => file == null
              ? AttachmentTapToDownload(
                  onTap: () => setState(() => _asked = true),
                )
              : _image(file),
        );
  }

  Widget _image(File file) {
    return Image.file(
      file,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      // The bytes behind an `s3_key` never change, so a frame already
      // decoded is always the right one to keep showing.
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => AttachmentImageFailure(
        onRetry: () => ref.invalidate(attachmentFileProvider(_key)),
      ),
    );
  }
}

/// What a picture looks like when auto-download says to wait for a tap.
///
/// Deliberately not a spinner: nothing is happening, and nothing will until
/// the reader says so.
class AttachmentTapToDownload extends StatelessWidget {
  const AttachmentTapToDownload({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_rounded,
              size: 22,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.attachmentTapToDownload,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grey ground an image sits on while it is being fetched.
class AttachmentImagePlaceholder extends StatelessWidget {
  const AttachmentImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// What is drawn instead of an image that would not come down.
///
/// The API says nothing about why a file is unavailable — a signature that
/// expired, a gateway hiccup and a genuinely broken object all look the same
/// (api-docs §5.5) — so the wording stays neutral and the only offer is to
/// try again.
class AttachmentImageFailure extends StatelessWidget {
  const AttachmentImageFailure({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.outline,
            size: 24,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              l10n.imageLoadFailed,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(l10n.retry),
            ),
        ],
      ),
    );
  }
}
