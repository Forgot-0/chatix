import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class VideoPreview extends ConsumerStatefulWidget {
  const VideoPreview({
    super.key,
    required this.attachment,
    required this.messageId,
    this.isCircular = false,
  });

  final AttachmentEntity attachment;
  final String messageId;

  final bool isCircular;

  @override
  ConsumerState<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<VideoPreview> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _initialising = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (_initialising) return;
    _initialising = true;

    final result = await ref
        .read(getAttachmentDownloadUrlUseCaseProvider)
        .execute(
          widget.attachment.chatId,
          widget.messageId,
          widget.attachment.id,
        );

    final url = result.getRight().toNullable()?.url ?? widget.attachment.url;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(widget.isCircular);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    final radius = widget.isCircular
        ? BorderRadius.circular(1000)
        : BorderRadius.circular(chatix.bubbleAnchorRadius * 2);

    final aspect = widget.isCircular
        ? 1.0
        : (widget.attachment.width != null &&
                  widget.attachment.height != null &&
                  widget.attachment.height! > 0
              ? (widget.attachment.width! / widget.attachment.height!).clamp(
                  0.6,
                  1.8,
                )
              : 1.4);

    final controller = _controller;

    Widget body;
    if (_failed) {
      body = Container(
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Text(
          AppLocalizations.of(context).imageLoadFailed,
          style: theme.textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      );
    } else if (controller == null) {
      body = Container(
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            const Center(
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow, color: Colors.white, size: 26),
              ),
            ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _duration(controller.value.duration),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: controller == null ? null : _togglePlay,
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: widget.isCircular ? 200 : null,
            child: AspectRatio(aspectRatio: aspect.toDouble(), child: body),
          ),
        ),
      ),
    );
  }

  static String _duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class VideoViewer extends StatelessWidget {
  const VideoViewer({
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
            VideoViewer(attachment: attachment, messageId: messageId),
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
        child: VideoPreview(attachment: attachment, messageId: messageId),
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
