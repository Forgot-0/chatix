import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/motion/motion.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/utils/attachment_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_media_gallery.dart';
import 'package:chatix/features/chat/presentation/utils/media_viewer_navigation.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/media_viewer/viewer_playback.dart';
import 'package:chatix/features/chat/presentation/widgets/message_album.dart';
import 'package:chatix/features/chat/presentation/widgets/video_poster_view.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One page of the viewer: a photo or a video, pinch- and double-tap
/// zoomable, inside the Hero that carries it out of the feed.
class ViewerMediaPage extends StatefulWidget {
  const ViewerMediaPage({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.playback,
    required this.onZoomChanged,
    required this.onTap,
  });

  final ChatMediaItem item;

  /// Whether this is the page on screen. Only that one fetches its video
  /// and plays it; a neighbour the page view keeps alive shows its poster.
  final bool isCurrent;

  final ViewerPlayback playback;
  final ValueChanged<bool> onZoomChanged;

  /// A single tap: shows or hides the bars.
  final VoidCallback onTap;

  @override
  State<ViewerMediaPage> createState() => _ViewerMediaPageState();
}

class _ViewerMediaPageState extends State<ViewerMediaPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  late final AnimationController _zoom;
  Animation<Matrix4>? _zoomTween;

  /// Where the second tap of a double tap came down: the point it zooms
  /// about.
  Offset? _doubleTapAt;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(vsync: this)..addListener(_onZoomTick);
  }

  @override
  void didUpdateWidget(ViewerMediaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Swiped away: the next time this page comes round it is whole again.
    if (oldWidget.isCurrent && !widget.isCurrent) {
      _zoom.stop();
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _zoom.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onZoomTick() {
    final tween = _zoomTween;
    if (tween != null) _transform.value = tween.value;
  }

  /// In by [MediaViewerLayout.doubleTapScale] about the tap, or back out.
  void _onDoubleTap() {
    final size = context.size;
    final focal =
        _doubleTapAt ?? (size == null ? Offset.zero : size.center(Offset.zero));

    final from = _transform.value.clone();
    final zoomIn = !ViewerZoom.isZoomed(from);
    final to = zoomIn
        ? ViewerZoom.about(focal, MediaViewerLayout.doubleTapScale)
        : Matrix4.identity();

    _zoomTween = Matrix4Tween(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _zoom,
        curve: context.motionCurve(AppMotion.standard),
      ),
    );
    _zoom.duration = context.motion(AppMotion.base);
    _zoom.forward(from: 0);

    widget.onZoomChanged(zoomIn);
  }

  void _onInteractionStart(ScaleStartDetails details) {
    if (_zoom.isAnimating) _zoom.stop();
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    widget.onZoomChanged(ViewerZoom.isZoomed(_transform.value));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: MediaViewerLayout.maxScale,
        // The mouse wheel turns pages here (the screen listens for it), so
        // it must not zoom as well. Pinching and double-clicking still do.
        scaleFactor: double.infinity,
        onInteractionStart: _onInteractionStart,
        onInteractionEnd: _onInteractionEnd,
        child: SizedBox.expand(
          child: item.isVideo
              ? _VideoContent(
                  item: item,
                  isCurrent: widget.isCurrent,
                  playback: widget.playback,
                )
              : _PhotoContent(item: item),
        ),
      ),
    );
  }
}

/// Width ÷ height as the server measured it (api-docs §5.5), or null.
double? _ratioOf(AttachmentEntity attachment) {
  final width = attachment.width;
  final height = attachment.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return width / height;
}

/// The box the picture actually occupies: its own shape, as large as the
/// screen allows, centred. The Hero is this box rather than the whole
/// screen, so the flight goes from the tile's rectangle to the picture's —
/// both cropped the same way ([BoxFit.cover]) — and nothing letterboxes or
/// jumps on landing. Without a known shape, the whole screen.
class _FittedFrame extends StatelessWidget {
  const _FittedFrame({required this.ratio, required this.child});

  final double? ratio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ratio = this.ratio;
    if (ratio == null) return SizedBox.expand(child: child);

    return Center(
      child: AspectRatio(aspectRatio: ratio, child: child),
    );
  }
}

class _PhotoContent extends StatelessWidget {
  const _PhotoContent({required this.item});

  final ChatMediaItem item;

  @override
  Widget build(BuildContext context) {
    final ratio = _ratioOf(item.attachment);

    return _FittedFrame(
      ratio: ratio,
      child: Hero(
        tag: attachmentHeroTag(item.attachmentId),
        flightShuttleBuilder: attachmentHeroFlight,
        child: AttachmentImage(
          attachment: item.attachment,
          messageId: item.messageId,
          // In its own shape the box is the picture, so covering it is
          // showing all of it — and matches how the tile filled its box.
          fit: ratio == null ? BoxFit.contain : BoxFit.cover,
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }
}

/// A video page: the poster at once — it is what flies in from the feed —
/// and the player over it as soon as the file is here and opened.
class _VideoContent extends ConsumerStatefulWidget {
  const _VideoContent({
    required this.item,
    required this.isCurrent,
    required this.playback,
  });

  final ChatMediaItem item;
  final bool isCurrent;
  final ViewerPlayback playback;

  @override
  ConsumerState<_VideoContent> createState() => _VideoContentState();
}

class _VideoContentState extends ConsumerState<_VideoContent> {
  AttachmentFileKey get _key => attachmentFileKey(
    widget.item.attachment,
    messageId: widget.item.messageId,
  );

  /// Opening the file is not something build can do, so it happens once
  /// the frame is out — and only if this is still the page on screen by
  /// then. [ViewerPlayback.open] is a no-op for a file already open.
  void _openWhenSettled(File file) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isCurrent) return;
      widget.playback.open(widget.item.attachmentId, file);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    final file = widget.isCurrent
        ? ref.watch(attachmentFileProvider(_key))
        : null;
    final local = file?.value;
    if (local != null) _openWhenSettled(local);

    return ListenableBuilder(
      listenable: widget.playback,
      builder: (context, _) {
        final controller = widget.playback.controllerOf(item.attachmentId);
        final unplayable = widget.playback.hasFailed(item.attachmentId);
        final downloadFailed = file?.hasError ?? false;

        final ratio =
            (controller != null && controller.value.aspectRatio > 0
                ? controller.value.aspectRatio
                : null) ??
            _ratioOf(item.attachment);

        return _FittedFrame(
          ratio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: attachmentHeroTag(item.attachmentId),
                flightShuttleBuilder: attachmentHeroFlight,
                child: VideoPosterView(
                  attachment: item.attachment,
                  messageId: item.messageId,
                  fit: ratio == null ? BoxFit.contain : BoxFit.cover,
                ),
              ),
              if (controller != null) VideoPlayer(controller),
              if (downloadFailed)
                AttachmentImageFailure(
                  onRetry: () => ref.invalidate(attachmentFileProvider(_key)),
                )
              else if (unplayable)
                _Unplayable(
                  onOpen: local == null
                      ? null
                      : () => AttachmentActions.open(
                          context,
                          ref,
                          attachment: item.attachment,
                          messageId: item.messageId,
                          local: local,
                        ),
                )
              else if (widget.isCurrent && controller == null)
                const Center(child: _Spinner()),
            ],
          ),
        );
      },
    );
  }
}

/// A video this device has no player for — `video_player` has nothing on
/// Windows or Linux — or one it cannot decode: said plainly, with the file
/// handed to whatever the system plays videos with.
class _Unplayable extends StatelessWidget {
  const _Unplayable({required this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ColoredBox(
      color: AppPalette.mediaScrim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.mediaViewerVideoUnplayable,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.onMediaScrim,
                ),
              ),
              if (onOpen != null) ...[
                const SizedBox(height: AppSpacing.x2),
                OutlinedButton.icon(
                  onPressed: onOpen,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.onMediaScrim,
                    side: const BorderSide(color: AppPalette.onViewerFaint),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l10n.mediaViewerOpenExternally),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: MediaViewerLayout.spinnerSize,
      child: CircularProgressIndicator(
        strokeWidth: MediaViewerLayout.spinnerStroke,
        color: AppPalette.onMediaScrim,
      ),
    );
  }
}

/// The big round play button over a paused video, in the middle of the
/// screen. Drawn by the screen, above the page rather than inside it, so a
/// tap on it is a tap on a button and not the first half of a double tap.
class ViewerCentrePlayButton extends StatelessWidget {
  const ViewerCentrePlayButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox.square(
      dimension: MediaViewerLayout.playButtonSize,
      child: Material(
        color: AppPalette.mediaScrim,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: l10n.videoPlay,
          onPressed: onPressed,
          color: AppPalette.onMediaScrim,
          iconSize: MediaViewerLayout.playIconSize,
          icon: const Icon(Icons.play_arrow_rounded),
        ),
      ),
    );
  }
}

/// [ViewerCentrePlayButton] for whichever video is open, while it is
/// paused.
class ViewerPausedOverlay extends StatelessWidget {
  const ViewerPausedOverlay({
    super.key,
    required this.playback,
    required this.attachmentId,
  });

  final ViewerPlayback playback;
  final String attachmentId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final controller = playback.controllerOf(attachmentId);
        if (controller == null) return const SizedBox.shrink();

        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.isPlaying
              ? const SizedBox.shrink()
              : Center(
                  child: ViewerCentrePlayButton(onPressed: playback.togglePlay),
                ),
        );
      },
    );
  }
}
