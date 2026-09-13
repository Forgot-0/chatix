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
class AttachmentImage extends ConsumerWidget {
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

  AttachmentFileKey get _key =>
      attachmentFileKey(attachment, messageId: messageId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = borderRadius ?? BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: radius,
      child: ref
          .watch(attachmentFileProvider(_key))
          .when(
            loading: () => const AttachmentImagePlaceholder(),
            error: (_, _) => AttachmentImageFailure(
              onRetry: () => ref.invalidate(attachmentFileProvider(_key)),
            ),
            data: (file) => _image(context, ref, file),
          ),
    );
  }

  Widget _image(BuildContext context, WidgetRef ref, File file) {
    return Image.file(
      file,
      fit: fit,
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
