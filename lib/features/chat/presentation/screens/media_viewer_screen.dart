import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/attachment_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_media_gallery.dart';
import 'package:chatix/features/chat/presentation/utils/forward_flow.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/message_album.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One photo or video, full screen, with the rest of the chat's media on
/// either side of it.
///
/// Behaves the way a viewer is expected to: pinch to zoom, drag down to put
/// it back (the conversation shows through as it goes), swipe sideways to
/// walk the chat's media, and a header saying whose it is and when.
///
/// The strip is frozen when the screen opens rather than watched, so a
/// message arriving mid-swipe cannot shuffle the page under a finger. It
/// comes from the loaded feed, because the API offers no media index — see
/// [ChatMediaGallery].
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.attachmentId,
  });

  final String chatId;
  final String messageId;
  final String attachmentId;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  /// How far down the sheet has to travel before letting go closes it.
  static const double _dismissThreshold = 120;

  /// The drag distance over which the conversation comes back into view.
  static const double _fadeDistance = 320;

  late final PageController _pageController;

  List<ChatMediaItem> _items = const [];
  int _index = 0;

  double _drag = 0;
  bool _isZoomed = false;

  TransferCancellation? _saving;
  double? _saveProgress;

  bool _isLoadingFallback = false;

  @override
  void initState() {
    super.initState();

    final loaded = ref.read(chatDetailProvider(widget.chatId)).value?.messages;
    final items = ChatMediaGallery.of(loaded ?? const []);
    final index = ChatMediaGallery.indexOf(items, widget.attachmentId);

    if (index >= 0) {
      _items = items;
      _index = index;
    } else {
      // Opened on media outside the loaded window — a deep link, or a feed
      // that has since been trimmed. One message is enough to show it.
      _isLoadingFallback = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOne());
    }

    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _saving?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadOne() async {
    final result = await ref
        .read(getMessageUseCaseProvider)
        .execute(widget.chatId, widget.messageId);

    if (!mounted) return;

    final message = result.getRight().toNullable();
    final items = message == null
        ? const <ChatMediaItem>[]
        : ChatMediaGallery.of([message]);
    final index = ChatMediaGallery.indexOf(items, widget.attachmentId);

    setState(() {
      _isLoadingFallback = false;
      _items = items;
      _index = index < 0 ? 0 : index;
    });

    if (_items.isNotEmpty && _pageController.hasClients) {
      _pageController.jumpToPage(_index);
    }
  }

  ChatMediaItem? get _current =>
      _index >= 0 && _index < _items.length ? _items[_index] : null;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() => _drag += details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isZoomed) return;

    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_drag.abs() > _dismissThreshold || velocity > 700) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _drag = 0);
  }

  Future<void> _save() async {
    final item = _current;
    if (item == null || _saving != null) return;

    final transfer = TransferCancellation();
    setState(() {
      _saving = transfer;
      _saveProgress = null;
    });

    await AttachmentActions.save(
      context,
      ref,
      attachment: item.attachment,
      messageId: item.messageId,
      cancellation: transfer,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() => _saveProgress = total > 0 ? received / total : null);
      },
    );

    if (!mounted) return;
    setState(() {
      _saving = null;
      _saveProgress = null;
    });
  }

  void _cancelSave() {
    _saving?.cancel();
    setState(() {
      _saving = null;
      _saveProgress = null;
    });
  }

  Future<void> _forward() async {
    final item = _current;
    if (item == null) return;

    await ForwardFlow.start(context, ref, message: item.message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 1 while the viewer is at rest, easing to 0 as it is dragged away, so
    // the conversation underneath comes back into view.
    final progress = (_drag.abs() / _fadeDistance).clamp(0.0, 1.0);
    final backdrop = 1 - progress;

    final item = _current;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: backdrop),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: Opacity(
                  opacity: math.max(0.3, backdrop),
                  child: _body(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              ignoring: progress > 0.1,
              child: AnimatedOpacity(
                opacity: progress > 0.1 ? 0 : 1,
                duration: AppMotion.fast,
                child: _Header(
                  item: item,
                  onClose: () => Navigator.of(context).pop(),
                  onSave: item == null ? null : _save,
                  onCancelSave: _cancelSave,
                  isSaving: _saving != null,
                  saveProgress: _saveProgress,
                  onForward: item == null ? null : _forward,
                ),
              ),
            ),
          ),
          if (item != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: progress > 0.1 ? 0 : 1,
                  duration: AppMotion.fast,
                  child: _Footer(
                    item: item,
                    position: _items.length > 1
                        ? l10n.mediaViewerCounter(_index + 1, _items.length)
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_isLoadingFallback) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Text(
            AppLocalizations.of(context).mediaViewerUnavailable,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      // A zoomed-in photo is being panned, not paged.
      physics: _isZoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      itemCount: _items.length,
      onPageChanged: (index) => setState(() {
        _index = index;
        _isZoomed = false;
      }),
      itemBuilder: (context, index) {
        final item = _items[index];

        return _MediaPage(
          key: ValueKey(item.attachmentId),
          item: item,
          isCurrent: index == _index,
          onZoomChanged: (zoomed) {
            if (_isZoomed == zoomed) return;
            setState(() => _isZoomed = zoomed);
          },
        );
      },
    );
  }
}

/// One page: the photo or the video, zoomable, with the Hero that carries it
/// out of the feed.
class _MediaPage extends StatefulWidget {
  const _MediaPage({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.onZoomChanged,
  });

  final ChatMediaItem item;
  final bool isCurrent;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  final TransformationController _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    final content = item.isVideo
        ? _ViewerVideo(item: item, autoPlay: widget.isCurrent)
        : AttachmentImage(
            attachment: item.attachment,
            messageId: item.messageId,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.zero,
          );

    return Center(
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        onInteractionEnd: _onInteractionEnd,
        child: Hero(
          tag: attachmentHeroTag(item.attachmentId),
          child: content,
        ),
      ),
    );
  }
}

/// A video played off the cached file, with the controls a full-screen
/// viewer needs and nothing more.
class _ViewerVideo extends ConsumerStatefulWidget {
  const _ViewerVideo({required this.item, required this.autoPlay});

  final ChatMediaItem item;
  final bool autoPlay;

  @override
  ConsumerState<_ViewerVideo> createState() => _ViewerVideoState();
}

class _ViewerVideoState extends ConsumerState<_ViewerVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;
  String? _preparedPath;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepare(File file) async {
    if (_preparedPath == file.path) return;
    _preparedPath = file.path;

    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
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
    if (widget.autoPlay) await controller.play();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = attachmentFileKey(
      widget.item.attachment,
      messageId: widget.item.messageId,
    );

    if (_failed) return const AttachmentImageFailure();

    return ref
        .watch(attachmentFileProvider(key))
        .when(
          loading: () => const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => AttachmentImageFailure(
            onRetry: () => ref.invalidate(attachmentFileProvider(key)),
          ),
          data: (file) {
            // The file is in hand; opening it is not something build can
            // do, so it happens once the frame is out. [_prepare] is a
            // no-op for a file it has already opened.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _prepare(file),
            );

            final controller = _controller;
            if (controller == null) {
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            return GestureDetector(
              onTap: _toggle,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                  if (!controller.value.isPlaying)
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.black54,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.onClose,
    required this.isSaving,
    required this.saveProgress,
    this.onSave,
    this.onCancelSave,
    this.onForward,
  });

  final ChatMediaItem? item;
  final VoidCallback onClose;
  final bool isSaving;
  final double? saveProgress;
  final VoidCallback? onSave;
  final VoidCallback? onCancelSave;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final message = item?.message;

    final local = message?.createdAt.toLocal();
    final when = local == null
        ? null
        : '${material.formatFullDate(local)}, '
              '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x1,
            AppSpacing.x1,
            AppSpacing.x2,
            AppSpacing.x3,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.close,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message == null
                          ? l10n.unknownProfile
                          : chatDisplayName(message.profile, message.authorId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (when != null)
                      Text(
                        when,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSaving)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x2,
                  ),
                  child: TransferProgressRing(
                    state: TransferRingState.running,
                    progress: saveProgress,
                    onPressed: onCancelSave,
                    size: 34,
                    semanticLabel: l10n.cancel,
                  ),
                )
              else
                IconButton(
                  tooltip: l10n.save,
                  onPressed: onSave,
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                  ),
                ),
              IconButton(
                tooltip: l10n.messageForward,
                onPressed: onForward,
                icon: const Icon(Icons.shortcut_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.item, this.position});

  final ChatMediaItem item;
  final String? position;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x4,
            AppSpacing.x4,
            AppSpacing.x3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.attachment.originalFilename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                [
                  ChatAttachmentLimits.formatBytes(item.attachment.size),
                  ?position,
                ].join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
