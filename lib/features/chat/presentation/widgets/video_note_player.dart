import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/ui/feedback/progress_ring.dart';
import 'package:chatix/core/ui/widgets/viewport_visibility.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/video_note_playback_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/message_album.dart';
import 'package:chatix/features/chat/presentation/widgets/video_note_viewer.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A video note in the feed: round, silent, and playing already.
///
/// Round because that is the whole of the form — the frame the camera
/// recorded is cropped to the circle inscribed in its shorter side here,
/// which is why the recorder only ever has to care that that side is under
/// 640 px and never that the frame is square (api-docs §5.5).
///
/// Played from the file cache rather than the link: a presigned URL is good
/// for 300 seconds, which is not long enough to survive a note being watched
/// twice, while the cached copy under its `s3_key` is good forever.
///
/// It starts on its own when it scrolls into view — without sound, and only
/// when the reader's autoplay setting allows it on this connection. A tap
/// adds the sound; a long press opens it full screen.
class VideoNotePlayer extends ConsumerWidget {
  const VideoNotePlayer({
    super.key,
    required this.attachment,
    required this.messageId,
  });

  final AttachmentEntity attachment;
  final String messageId;

  /// How big a note is drawn in the feed.
  static const double diameter = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = attachmentFileKey(attachment, messageId: messageId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox.square(
        dimension: diameter,
        child: ref
            .watch(attachmentFileProvider(key))
            .when(
              loading: () => const ClipOval(child: AttachmentImagePlaceholder()),
              error: (_, _) => ClipOval(
                child: AttachmentImageFailure(
                  onRetry: () => ref.invalidate(attachmentFileProvider(key)),
                ),
              ),
              data: (file) => _Round(
                file: file,
                attachmentId: attachment.id,
                declared: attachment.durationSeconds,
              ),
            ),
      ),
    );
  }
}

class _Round extends ConsumerStatefulWidget {
  const _Round({
    required this.file,
    required this.attachmentId,
    required this.declared,
  });

  final File file;
  final String attachmentId;

  /// What the gateway measured, where it has finished measuring. Stands in
  /// for the real duration until the file is open.
  final int? declared;

  @override
  ConsumerState<_Round> createState() => _RoundState();
}

class _RoundState extends ConsumerState<_Round> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _onScreen = false;

  /// The viewer is open over this note. It has the sound and the picture;
  /// this one waits.
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void didUpdateWidget(_Round oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path == widget.file.path) return;

    _controller?.dispose();
    _controller = null;
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Nothing to hand back: a note leaves the tree only after it has left
    // the viewport, and leaving the viewport is already what drops the
    // sound. Reaching for a provider from `dispose` would only add a way
    // for a torn-down scope to throw.
    super.dispose();
  }

  Future<void> _prepare() async {
    final controller = VideoPlayerController.file(widget.file);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
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
    _sync();
  }

  bool get _hasSound => ref.read(videoNoteSoundProvider) == widget.attachmentId;

  /// Brings the player in line with what the reader has asked for and what
  /// is actually on screen. The one place playback is decided, so the
  /// setting, the connection, the scroll position and the tap cannot each
  /// hold a different opinion.
  void _sync() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final hasSound = _hasSound;
    final shouldPlay = videoNoteShouldPlay(
      onScreen: _onScreen,
      hasSound: hasSound,
      autoplayAllowed: ref.read(videoNoteAutoplayProvider),
      handedOver: _handedOver,
    );

    unawaited(controller.setVolume(hasSound ? 1 : 0));

    if (shouldPlay && !controller.value.isPlaying) {
      unawaited(controller.play());
    } else if (!shouldPlay && controller.value.isPlaying) {
      unawaited(controller.pause());
    }
  }

  void _onVisibility(double fraction) {
    final onScreen = videoNoteIsOnScreen(
      visible: fraction,
      wasOnScreen: _onScreen,
    );

    if (onScreen == _onScreen) return;
    _onScreen = onScreen;

    // A note scrolled away takes its sound with it: the reader turned it on
    // for something they were looking at.
    if (!onScreen && _hasSound) {
      ref.read(videoNoteSoundProvider.notifier).silence();
      return;
    }
    _sync();
  }

  void _toggleSound() {
    if (_controller == null) return;
    ref.read(videoNoteSoundProvider.notifier).toggle(widget.attachmentId);
  }

  Future<void> _openFullScreen() async {
    final controller = _controller;
    if (controller == null) return;

    unawaited(HapticFeedback.mediumImpact());

    setState(() => _handedOver = true);
    _sync();

    await VideoNoteViewer.show(
      context,
      file: widget.file,
      startAt: controller.value.position,
    );

    if (!mounted) return;
    setState(() => _handedOver = false);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    // Changes to either of these are decisions the reader made elsewhere —
    // in settings, or by tapping another note — and both land here.
    ref.listen(videoNoteSoundProvider, (_, _) => _sync());
    ref.listen(videoNoteAutoplayProvider, (_, _) => _sync());

    if (_failed) return const ClipOval(child: AttachmentImageFailure());

    final controller = _controller;
    if (controller == null) {
      return const ClipOval(child: AttachmentImagePlaceholder());
    }

    final scheme = Theme.of(context).colorScheme;
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    final hasSound = ref.watch(videoNoteSoundProvider) == widget.attachmentId;

    return ViewportVisibility(
      onVisibilityChanged: _onVisibility,
      child: Semantics(
        button: true,
        label: l10n.videoNotePlayerLabel(
          formatMediaDuration(_lengthOf(controller)),
        ),
        hint: hasSound ? l10n.videoNoteTapToMute : l10n.videoNoteTapForSound,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: _toggleSound,
            onLongPress: () => unawaited(_openFullScreen()),
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) => ProgressRing(
                progress: _progressOf(value),
                stroke: 3,
                color: hasSound ? scheme.primary : chatix.success,
                trackColor: scheme.outlineVariant.withValues(alpha: 0.5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child!,
                    // Silence is the default, so it is the state that has to
                    // say so: a muted note carries the crossed-out speaker,
                    // one with sound carries the plain one.
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: _Pill(
                        icon: hasSound
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        label: formatMediaDuration(
                          _remainingOf(value, controller),
                        ),
                      ),
                    ),
                    // Nothing is playing and nothing will start on its own:
                    // the note says what a tap would do rather than sitting
                    // on a still frame looking broken.
                    if (!value.isPlaying && !_handedOver)
                      Center(
                        child: _Pill(
                          icon: Icons.play_arrow_rounded,
                          label: l10n.videoNoteAutoplayOff,
                        ),
                      ),
                  ],
                ),
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  // The circle takes the middle of whatever shape the frame
                  // is, rather than squashing a face to fit it.
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
          ),
        ),
      ),
    );
  }

  Duration _lengthOf(VideoPlayerController controller) {
    final measured = controller.value.duration;
    if (measured > Duration.zero) return measured;
    return Duration(seconds: widget.declared ?? 0);
  }

  double _progressOf(VideoPlayerValue value) {
    final total = value.duration.inMilliseconds;
    if (total <= 0) return 0;
    return value.position.inMilliseconds / total;
  }

  /// What is left, counting down — the number that matters while watching.
  Duration _remainingOf(
    VideoPlayerValue value,
    VideoPlayerController controller,
  ) {
    final left = _lengthOf(controller) - value.position;
    return left.isNegative ? Duration.zero : left;
  }
}

/// A dark lozenge over the picture: an icon and a number, readable on
/// whatever happens to be behind it in either theme.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
