import 'package:flutter/material.dart';

import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/motion/motion.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_media_gallery.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/video_poster_view.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The viewer's top bar: the way out, whose photo it is and when it was
/// sent, and where it sits in the chat's media.
class ViewerTopBar extends StatelessWidget {
  const ViewerTopBar({
    super.key,
    required this.item,
    required this.onClose,
    this.position,
  });

  final ChatMediaItem? item;
  final VoidCallback onClose;

  /// "3 of 12", or null when there is only the one.
  final String? position;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final message = item?.message;

    final when = message == null
        ? null
        : AppDateFormat.of(context).fullDateTime(message.createdAt);
    final position = this.position;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppPalette.viewerShade, AppPalette.viewerShadeClear],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x1,
            AppSpacing.x1,
            AppSpacing.x4,
            AppSpacing.x5,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.close,
                onPressed: onClose,
                color: AppPalette.onMediaScrim,
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: AppSpacing.x1),
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
                      style: text.titleSmall?.copyWith(
                        color: AppPalette.onMediaScrim,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (when != null)
                      Text(
                        when,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: AppPalette.onViewerMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (position != null) ...[
                const SizedBox(width: AppSpacing.x3),
                Text(
                  position,
                  style: text.labelLarge?.copyWith(
                    color: AppPalette.onViewerMuted,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The viewer's bottom panel: a video's controls, the caption, the strip of
/// thumbnails on a wide screen, and what can be done with what is open.
class ViewerBottomBar extends StatelessWidget {
  const ViewerBottomBar({
    super.key,
    required this.actions,
    this.controls,
    this.caption,
    this.strip,
    this.isWide = false,
  });

  final List<Widget> actions;
  final Widget? controls;
  final Widget? caption;
  final Widget? strip;

  /// On a wide screen the buttons sit together in the middle; on a phone
  /// they share the width, the way a tab bar does.
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final controls = this.controls;
    final caption = this.caption;
    final strip = this.strip;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppPalette.viewerShade, AppPalette.viewerShadeClear],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x2,
            AppSpacing.x8,
            AppSpacing.x2,
            AppSpacing.x1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controls != null)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: MediaViewerLayout.controlsMaxWidth,
                    ),
                    child: controls,
                  ),
                ),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x2,
                    AppSpacing.x1,
                    AppSpacing.x2,
                    AppSpacing.x2,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: MediaViewerLayout.captionMaxWidth,
                      ),
                      child: caption,
                    ),
                  ),
                ),
              ?strip,
              Row(
                mainAxisAlignment: isWide
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (isWide && i > 0) const SizedBox(width: AppSpacing.x3),
                    actions[i],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the bottom bar's buttons.
class ViewerActionButton extends StatelessWidget {
  const ViewerActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: AppPalette.onMediaScrim,
      icon: Icon(icon),
    );
  }
}

/// The message's text under its photo, folded to a few lines when it is
/// long — the picture is what the screen is for — with a way to open it.
class ViewerCaption extends StatefulWidget {
  const ViewerCaption({super.key, required this.text, required this.maxHeight});

  final String text;

  /// The most an opened caption may take before it scrolls.
  final double maxHeight;

  @override
  State<ViewerCaption> createState() => _ViewerCaptionState();
}

class _ViewerCaptionState extends State<ViewerCaption> {
  bool _isOpen = false;

  @override
  void didUpdateWidget(ViewerCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another photo's caption starts folded again.
    if (oldWidget.text != widget.text) _isOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppPalette.onMediaScrim);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: MediaViewerLayout.captionFoldedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final folds = painter.didExceedMaxLines;
        painter.dispose();

        if (!folds) return Text(widget.text, style: style);

        final toggle = TextButton(
          onPressed: () => setState(() => _isOpen = !_isOpen),
          // Flush with the caption's own left edge: no padding, and no
          // minimum width to centre the word in.
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.onMediaScrim,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, MediaViewerLayout.captionToggleHeight),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          child: Text(
            _isOpen ? l10n.mediaViewerCaptionLess : l10n.mediaViewerCaptionMore,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isOpen)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight),
                child: SingleChildScrollView(
                  child: Text(widget.text, style: style),
                ),
              )
            else
              Text(
                widget.text,
                style: style,
                maxLines: MediaViewerLayout.captionFoldedLines,
                overflow: TextOverflow.ellipsis,
              ),
            toggle,
          ],
        );
      },
    );
  }
}

/// The chat's media as a row of thumbnails, the open one ringed and kept in
/// the middle. Only on a wide screen: on a phone the swipe is the strip.
class ViewerThumbnailStrip extends StatefulWidget {
  const ViewerThumbnailStrip({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
  });

  final List<ChatMediaItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  State<ViewerThumbnailStrip> createState() => _ViewerThumbnailStripState();
}

class _ViewerThumbnailStripState extends State<ViewerThumbnailStrip> {
  final ScrollController _scroll = ScrollController();

  static const double _pitch =
      MediaViewerLayout.thumbnailSize + MediaViewerLayout.thumbnailGap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centre(animate: false),
    );
  }

  @override
  void didUpdateWidget(ViewerThumbnailStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _centre(animate: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _centre({required bool animate}) {
    if (!mounted || !_scroll.hasClients) return;

    final position = _scroll.position;
    final target =
        (widget.index * _pitch +
                MediaViewerLayout.thumbnailSize / 2 -
                position.viewportDimension / 2 +
                AppSpacing.x2)
            .clamp(position.minScrollExtent, position.maxScrollExtent);

    final duration = context.motion(AppMotion.base);
    if (!animate || duration == Duration.zero) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: duration, curve: AppMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = widget.items;

    return SizedBox(
      height: MediaViewerLayout.stripHeight,
      child: Center(
        child: ListView.separated(
          controller: _scroll,
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: AppSpacing.x2,
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: MediaViewerLayout.thumbnailGap),
          itemBuilder: (context, index) => _Thumbnail(
            item: items[index],
            isOpen: index == widget.index,
            label: l10n.mediaViewerCounter(index + 1, items.length),
            onTap: () => widget.onSelect(index),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.item,
    required this.isOpen,
    required this.label,
    required this.onTap,
  });

  final ChatMediaItem item;
  final bool isOpen;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.primary;

    // No Hero here: the open page already carries this attachment's tag,
    // and two of them on one route is an error.
    final picture = item.isVideo
        ? Stack(
            fit: StackFit.expand,
            children: [
              VideoPosterView(
                attachment: item.attachment,
                messageId: item.messageId,
              ),
              const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: AppPalette.onMediaScrim,
                ),
              ),
            ],
          )
        : AttachmentImage(
            attachment: item.attachment,
            messageId: item.messageId,
            borderRadius: BorderRadius.zero,
            fallback: const ColoredBox(
              color: AppPalette.videoGroundBottom,
              child: Icon(
                Icons.image_outlined,
                color: AppPalette.onViewerMuted,
              ),
            ),
          );

    return Semantics(
      button: true,
      selected: isOpen,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: MediaViewerLayout.thumbnailSize,
          height: MediaViewerLayout.thumbnailSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              MediaViewerLayout.thumbnailRadius,
            ),
            border: Border.all(
              color: isOpen ? ring : AppPalette.viewerShadeClear,
              width: MediaViewerLayout.thumbnailRing,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              MediaViewerLayout.thumbnailRadius -
                  MediaViewerLayout.thumbnailRing / 2,
            ),
            child: AnimatedOpacity(
              opacity: isOpen ? 1 : MediaViewerLayout.thumbnailIdleOpacity,
              duration: AppMotion.fast,
              child: picture,
            ),
          ),
        ),
      ),
    );
  }
}

/// An arrow at the side of a wide viewer, for whoever has a mouse and no
/// swipe.
class ViewerSideArrow extends StatelessWidget {
  const ViewerSideArrow({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: MediaViewerLayout.arrowButtonSize,
      child: Material(
        color: AppPalette.mediaScrim,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          color: AppPalette.onMediaScrim,
          iconSize: MediaViewerLayout.arrowIconSize,
          icon: Icon(icon),
        ),
      ),
    );
  }
}
