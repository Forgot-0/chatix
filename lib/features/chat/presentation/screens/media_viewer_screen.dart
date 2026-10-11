import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/storage/file_sharer.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/core/ui/motion/motion.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/attachment_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_media_gallery.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/forward_flow.dart';
import 'package:chatix/features/chat/presentation/utils/media_viewer_navigation.dart';
import 'package:chatix/features/chat/presentation/widgets/media_viewer/viewer_chrome.dart';
import 'package:chatix/features/chat/presentation/widgets/media_viewer/viewer_media_page.dart';
import 'package:chatix/features/chat/presentation/widgets/media_viewer/viewer_playback.dart';
import 'package:chatix/features/chat/presentation/widgets/media_viewer/viewer_video_controls.dart';
import 'package:chatix/features/chat/presentation/widgets/message_delete_dialog.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One photo or video, full screen, with the rest of the chat's media on
/// either side of it.
///
/// Behaves the way a viewer is expected to: pinch or double-tap to zoom,
/// drag down to put it back (the conversation shows through as it goes),
/// swipe sideways — or use the arrow keys, the mouse wheel, the arrows at
/// the sides and the strip of thumbnails on a wide screen — to walk the
/// chat's media, and a tap to clear everything off the picture. The bars say
/// whose it is, when, and where it sits in the chat's media, and offer what
/// can be done with it: share, forward, find it in the chat, save, delete.
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
  late final PageController _pageController;
  final ViewerPlayback _playback = ViewerPlayback();
  final FocusNode _focus = FocusNode(debugLabel: 'MediaViewer');
  final WheelPager _wheel = WheelPager();

  List<ChatMediaItem> _items = const [];
  int _index = 0;

  double _drag = 0;
  bool _isZoomed = false;

  /// Whether the bars are up. A tap on the picture puts them away, and
  /// another brings them back.
  bool _barsShown = true;

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
    _playback.dispose();
    _focus.dispose();
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

  MediaViewerCursor get _cursor =>
      MediaViewerCursor(index: _index, length: _items.length);

  // ------------------------------------------------------------ moving about

  /// Turns to [target], the way a swipe would; nothing for null.
  void _goTo(int? target) {
    if (target == null || !_pageController.hasClients) return;

    final duration = context.motion(AppMotion.slow);
    if (duration == Duration.zero) {
      _pageController.jumpToPage(target);
      return;
    }
    unawaited(
      _pageController.animateToPage(
        target,
        duration: duration,
        curve: AppMotion.standard,
      ),
    );
  }

  void _onPageChanged(int index) {
    // Whatever was playing on the page just left stops with it.
    _playback.close();
    setState(() {
      _index = index;
      _isZoomed = false;
    });
  }

  void _close() => Navigator.of(context).pop();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (MediaViewerKeys.closes(key)) {
      if (event is KeyDownEvent) _close();
      return KeyEventResult.handled;
    }

    final step = MediaViewerKeys.stepFor(key);
    if (step != null) {
      // A zoomed photo is being looked at closely, not paged through.
      if (!_isZoomed) _goTo(_cursor.step(step));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.space && (_current?.isVideo ?? false)) {
      if (event is KeyDownEvent) _playback.togglePlay();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    // Only the vertical wheel: a sideways one already scrolls the page view
    // itself.
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    if (_isZoomed) return;

    final step = _wheel.scroll(event.scrollDelta.dy, event.timeStamp);
    if (step != null) _goTo(_cursor.step(step));
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() => _drag += details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isZoomed) return;

    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_drag.abs() > MediaViewerLayout.dismissDistance ||
        velocity > MediaViewerLayout.dismissVelocity) {
      _close();
      return;
    }

    setState(() => _drag = 0);
  }

  // ----------------------------------------------------------------- actions

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

  Future<void> _share(BuildContext buttonContext) async {
    final item = _current;
    if (item == null) return;

    await AttachmentActions.share(
      buttonContext,
      ref,
      attachment: item.attachment,
      messageId: item.messageId,
    );
  }

  Future<void> _forward() async {
    final item = _current;
    if (item == null) return;

    await ForwardFlow.start(context, ref, message: item.message);
  }

  /// Closes the viewer onto the conversation, scrolled to the message the
  /// picture came in and lit up — however the viewer was reached.
  Future<void> _showInChat() async {
    final item = _current;
    if (item == null) return;

    // All read before the viewer goes: its context goes with it.
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notifier = ref.read(chatDetailProvider(widget.chatId).notifier);
    final router = GoRouter.maybeOf(context);

    if (router != null) {
      // Opened from the chat, this is a pop; from the chat's profile, it
      // takes the profile with it.
      router.go(ChatDetailRoute(widget.chatId).location);
    } else {
      Navigator.of(context).pop();
    }

    final found = await notifier.revealMessage(
      item.messageId,
      seq: item.message.seq,
    );
    if (!found) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.messageNotFound)));
    }
  }

  /// Deletes the message the picture came in — the API deletes messages,
  /// not attachments (api-docs §5.4), so an album goes whole, and the
  /// question says so.
  Future<void> _delete() async {
    final item = _current;
    if (item == null) return;

    final l10n = AppLocalizations.of(context);
    final attachments = item.message.attachments.length;

    final confirmed = await MessageDeleteDialog.confirm(
      context,
      count: 1,
      detail: attachments > 1 ? l10n.mediaViewerDeleteAlbum(attachments) : null,
    );
    if (!confirmed || !mounted) return;

    final failure = await ref
        .read(chatDetailProvider(widget.chatId).notifier)
        .tryDeleteMessage(item.messageId);
    if (!mounted) return;

    if (failure != null) {
      AppSnackbar.failure(
        context,
        friendlyFailureMessage(
          failure,
          l10n: l10n,
          fallback: l10n.messageDeleteFailed,
        ),
      );
      return;
    }

    final removed = {
      for (var i = 0; i < _items.length; i++)
        if (_items[i].messageId == item.messageId) i,
    };
    final next = _cursor.afterRemoval(removed);
    if (next == null) {
      _close();
      return;
    }

    _playback.close();
    setState(() {
      _items = [
        for (var i = 0; i < _items.length; i++)
          if (!removed.contains(i)) _items[i],
      ];
      _index = next;
      _isZoomed = false;
    });
    _pageController.jumpToPage(next);
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 1 while the viewer is at rest, easing to 0 as it is dragged away, so
    // the conversation underneath comes back into view.
    final progress = (_drag.abs() / MediaViewerLayout.fadeDistance).clamp(
      0.0,
      1.0,
    );
    final backdrop = 1 - progress;
    final barsShown = _barsShown && progress <= MediaViewerLayout.barsHideAt;

    final item = _current;

    // Watched here rather than where they are used: that is inside a
    // LayoutBuilder, which runs during layout, not during this build.
    final rights = ref.watch(
      chatDetailProvider(widget.chatId).select((detail) {
        final state = detail.value;
        return (chat: state?.chat, me: state?.me);
      }),
    );
    final canDelete =
        item != null &&
        canDeleteMessage(rights.chat, rights.me, item.message.authorId);
    final canShare = ref.watch(fileSharerProvider).isSupported;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= MediaViewerLayout.wideFrom;

              return Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppPalette.viewerGround.withValues(
                        alpha: backdrop,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: Transform.translate(
                        offset: Offset(0, _drag),
                        child: Opacity(
                          opacity: math.max(
                            MediaViewerLayout.dragMinOpacity,
                            backdrop,
                          ),
                          child: _body(),
                        ),
                      ),
                    ),
                  ),
                  if (item != null && item.isVideo)
                    Positioned.fill(
                      child: _Fade(
                        shown: barsShown,
                        child: ViewerPausedOverlay(
                          playback: _playback,
                          attachmentId: item.attachmentId,
                        ),
                      ),
                    ),
                  if (isWide && _items.length > 1) ..._arrows(l10n, barsShown),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: _Fade(
                      shown: barsShown,
                      child: ViewerTopBar(
                        item: item,
                        onClose: _close,
                        position: _items.length > 1
                            ? l10n.mediaViewerCounter(
                                _cursor.position,
                                _items.length,
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (item != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _Fade(
                        shown: barsShown,
                        child: _bottomBar(
                          item,
                          isWide: isWide,
                          height: constraints.maxHeight,
                          canDelete: canDelete,
                          canShare: canShare,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _arrows(AppLocalizations l10n, bool shown) {
    Widget side({required bool left}) {
      final target = _cursor.step(left ? -1 : 1);

      return Positioned(
        left: left ? AppSpacing.x3 : null,
        right: left ? null : AppSpacing.x3,
        top: 0,
        bottom: 0,
        child: Center(
          child: _Fade(
            shown: shown && target != null,
            child: ViewerSideArrow(
              icon: left
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              tooltip: left ? l10n.mediaViewerPrevious : l10n.mediaViewerNext,
              onPressed: () => _goTo(target),
            ),
          ),
        ),
      );
    }

    return [side(left: true), side(left: false)];
  }

  Widget _bottomBar(
    ChatMediaItem item, {
    required bool isWide,
    required double height,
    required bool canDelete,
    required bool canShare,
  }) {
    final l10n = AppLocalizations.of(context);
    final caption = item.message.content?.trim();

    return ViewerBottomBar(
      isWide: isWide,
      controls: item.isVideo
          ? ListenableBuilder(
              listenable: _playback,
              builder: (context, _) {
                final controller = _playback.controllerOf(item.attachmentId);
                if (controller == null) return const SizedBox.shrink();

                return ViewerVideoControls(
                  controller: controller,
                  playback: _playback,
                  showVolume: viewerHasVolumeSlider,
                );
              },
            )
          : null,
      caption: caption == null || caption.isEmpty
          ? null
          : ViewerCaption(
              text: caption,
              maxHeight: height * MediaViewerLayout.captionOpenMaxHeightFactor,
            ),
      strip: isWide && _items.length > 1
          ? ViewerThumbnailStrip(
              items: _items,
              index: _index,
              onSelect: (index) => _goTo(_cursor.jumpTo(index)),
            )
          : null,
      actions: [
        if (canShare)
          Builder(
            builder: (buttonContext) => ViewerActionButton(
              icon: Icons.share_rounded,
              tooltip: l10n.messageShareFile,
              onPressed: () => _share(buttonContext),
            ),
          ),
        ViewerActionButton(
          icon: Icons.shortcut_rounded,
          tooltip: l10n.messageForward,
          onPressed: _forward,
        ),
        ViewerActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: l10n.mediaViewerShowInChat,
          onPressed: _showInChat,
        ),
        if (_saving != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x1),
            child: TransferProgressRing(
              state: TransferRingState.running,
              progress: _saveProgress,
              onPressed: _cancelSave,
              size: MediaViewerLayout.arrowButtonSize - AppSpacing.x2,
              semanticLabel: l10n.cancel,
            ),
          )
        else
          ViewerActionButton(
            icon: Icons.download_rounded,
            tooltip: l10n.save,
            onPressed: _save,
          ),
        if (canDelete)
          ViewerActionButton(
            icon: Icons.delete_outline_rounded,
            tooltip: l10n.messageDelete,
            onPressed: _delete,
          ),
      ],
    );
  }

  Widget _body() {
    if (_isLoadingFallback) {
      return const Center(
        child: SizedBox.square(
          dimension: MediaViewerLayout.spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: MediaViewerLayout.spinnerStroke,
          ),
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
            style: const TextStyle(color: AppPalette.onViewerMuted),
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
      onPageChanged: _onPageChanged,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final index = ChatMediaGallery.indexOf(_items, key.value);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) {
        final item = _items[index];

        return ViewerMediaPage(
          key: ValueKey(item.attachmentId),
          item: item,
          isCurrent: index == _index,
          playback: _playback,
          onTap: () => setState(() => _barsShown = !_barsShown),
          onZoomChanged: (zoomed) {
            if (_isZoomed == zoomed) return;
            setState(() => _isZoomed = zoomed);
          },
        );
      },
    );
  }
}

/// Fades a bar in and out, and takes it out of hit testing while it is
/// away so a tap where it was reaches the picture.
class _Fade extends StatelessWidget {
  const _Fade({required this.shown, required this.child});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !shown,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: context.motion(AppMotion.fast),
        child: child,
      ),
    );
  }
}
