import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/message_album.dart';

/// A video played from the file cache.
///
/// The file rather than the link: a presigned URL is good for 300 seconds
/// (api-docs §5.5), which is not long enough to survive a video note being
/// watched twice, while the cached copy under its `s3_key` is good forever.
/// A video note is small by construction (≤ 40 MB, ≤ 60 s), so having the
/// whole file before the first frame costs little and buys playback that
/// cannot expire mid-way.
class VideoPreview extends ConsumerWidget {
  const VideoPreview({
    super.key,
    required this.attachment,
    required this.messageId,
    this.isCircular = false,
  });

  final AttachmentEntity attachment;
  final String messageId;

  /// Video notes are round and loop; ordinary videos are neither.
  final bool isCircular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatix = ChatixTheme.of(context);

    final radius = isCircular
        ? BorderRadius.circular(1000)
        : BorderRadius.circular(chatix.bubbleAnchorRadius * 2);

    final aspect = isCircular ? 1.0 : _aspectOf(attachment);
    final key = attachmentFileKey(attachment, messageId: messageId);

    final body = ref
        .watch(attachmentFileProvider(key))
        .when(
          loading: () => const AttachmentImagePlaceholder(),
          error: (_, _) => AttachmentImageFailure(
            onRetry: () => ref.invalidate(attachmentFileProvider(key)),
          ),
          data: (file) => _VideoSurface(
            file: file,
            isCircular: isCircular,
            duration: attachment.durationSeconds,
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: isCircular ? 200 : null,
          child: AspectRatio(aspectRatio: aspect, child: body),
        ),
      ),
    );
  }

  static double _aspectOf(AttachmentEntity attachment) {
    final width = attachment.width;
    final height = attachment.height;
    if (width == null || height == null || height <= 0) return 1.4;

    return (width / height).clamp(0.6, 1.8).toDouble();
  }
}

class _VideoSurface extends StatefulWidget {
  const _VideoSurface({
    required this.file,
    required this.isCircular,
    required this.duration,
  });

  final File file;
  final bool isCircular;
  final int? duration;

  @override
  State<_VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<_VideoSurface> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(_VideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path == widget.file.path) return;

    _controller?.dispose();
    _controller = null;
    _prepare();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final controller = VideoPlayerController.file(widget.file);
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
    if (_failed) return const AttachmentImageFailure();

    final controller = _controller;
    if (controller == null) return const AttachmentImagePlaceholder();

    final seconds = widget.duration;
    final duration = controller.value.duration.inSeconds > 0
        ? controller.value.duration
        : Duration(seconds: seconds ?? 0);

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
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
          if (duration > Duration.zero)
            Positioned(
              right: 6,
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
                  formatMediaDuration(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
