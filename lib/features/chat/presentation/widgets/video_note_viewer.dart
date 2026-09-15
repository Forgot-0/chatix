import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/progress_ring.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/message_album.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One video note, as large as the screen will draw it, with the sound on.
///
/// A modal over the conversation rather than a route of its own: there is
/// nothing to link to — the file is on this device and the note is one of
/// many in a feed that is already open behind it — and dismissing it should
/// put the reader back exactly where they were, mid-scroll.
///
/// Still round. A video note is round everywhere, and squaring it up here
/// would show the reader parts of the frame nobody framed.
class VideoNoteViewer extends StatefulWidget {
  const VideoNoteViewer({
    super.key,
    required this.file,
    this.startAt = Duration.zero,
  });

  final File file;

  /// Where the note in the feed had got to. Picking it up there rather than
  /// at zero is what makes the long press read as "bigger", not "again".
  final Duration startAt;

  static Future<void> show(
    BuildContext context, {
    required File file,
    Duration startAt = Duration.zero,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: AppMotion.base,
      pageBuilder: (_, _, _) => VideoNoteViewer(file: file, startAt: startAt),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: AppMotion.curve),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(
            CurvedAnimation(parent: animation, curve: AppMotion.curve),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  State<VideoNoteViewer> createState() => _VideoNoteViewerState();
}

class _VideoNoteViewerState extends State<VideoNoteViewer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
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
      await controller.setLooping(true);
      await controller.setVolume(1);
      await controller.seekTo(widget.startAt);
      await controller.play();
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

    controller.value.isPlaying
        ? unawaited(controller.pause())
        : unawaited(controller.play());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);

    // As big as the narrow side allows, less the room the close button and
    // the clock need. A circle that touches both edges has nowhere to be
    // dismissed from.
    final diameter =
        (media.size.shortestSide - AppSpacing.x8).clamp(160.0, 520.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Anywhere outside the circle closes it, which is the gesture
          // everyone already tries first.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Center(
            child: SizedBox.square(
              dimension: diameter,
              child: _body(diameter),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x2),
                child: IconButton.filledTonal(
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(double diameter) {
    if (_failed) return const ClipOval(child: AttachmentImageFailure());

    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          final total = value.duration.inMilliseconds;

          return ProgressRing(
            progress: total <= 0 ? 0 : value.position.inMilliseconds / total,
            stroke: 4,
            color: Theme.of(context).colorScheme.primary,
            trackColor: Colors.white24,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child!,
                if (!value.isPlaying)
                  const Center(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.black54,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: diameter * 0.08,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x3,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text(
                        formatMediaDuration(value.position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: ClipOval(
          child: ColoredBox(
            color: Colors.black,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
