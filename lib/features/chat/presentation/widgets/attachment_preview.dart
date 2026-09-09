import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_url_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

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
  bool _refreshed = false;

  AttachmentRef get _ref => (
    chatId: widget.attachment.chatId,
    messageId: widget.messageId,
    attachmentId: widget.attachment.id,
  );

  @override
  Widget build(BuildContext context) {
    final inline = widget.attachment.url;

    if (inline != null && inline.isNotEmpty && !_refreshed) {
      return _image(inline);
    }

    return ref
        .watch(attachmentDownloadUrlProvider(_ref))
        .when(loading: _placeholder, error: (_, _) => _failed(), data: _image);
  }

  Widget _image(String url) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: widget.attachment.s3Key,
        fit: widget.fit,
        width: double.infinity,
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) {
          if (!_refreshed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _refreshed) return;
              setState(() => _refreshed = true);
              ref.invalidate(attachmentDownloadUrlProvider(_ref));
            });
            return _placeholder();
          }
          return _failed();
        },
      ),
    );
  }

  Widget _placeholder() {
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

  Widget _failed() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.outline,
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).imageLoadFailed,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AttachmentViewer extends StatelessWidget {
  const AttachmentViewer({
    super.key,
    required this.attachment,
    required this.messageId,
  });

  final AttachmentEntity attachment;
  final String messageId;

  static Future<void> open(
    BuildContext context, {
    required AttachmentEntity attachment,
    required String messageId,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            AttachmentViewer(attachment: attachment, messageId: messageId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          attachment.originalFilename,
          style: const TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: l10n.close,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: AttachmentImage(
            attachment: attachment,
            messageId: messageId,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            ChatAttachmentLimits.formatBytes(attachment.size),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
