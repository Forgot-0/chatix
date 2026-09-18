import 'package:flutter/material.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/wallpaper/mesh_wallpaper.dart';
import 'package:chatix/features/chat/presentation/widgets/bubble_shape.dart';
import 'package:chatix/features/chat/presentation/widgets/typing_dots.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A working conversation, three bubbles tall, sitting on the settings
/// screen.
///
/// Not a picture of a chat: it is painted by the same wallpaper painter, cut
/// by the same [BubbleShape], padded by the same density and scaled by the
/// same text scale as the real thing, so there is no way for it to agree
/// with the sliders and disagree with the chat. The typing indicator is live
/// — and stops moving on its own when the system asks for reduced motion.
class AppearancePreview extends StatelessWidget {
  const AppearancePreview({super.key});

  /// Varies the wallpaper layout away from any real chat's, so the preview
  /// is recognisably a sample rather than a specific conversation.
  static const int layoutSeed = 7;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    final spec = wallpaperSpecOf(context, layoutSeed: layoutSeed);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: MeshWallpaperView(
        spec: spec,
        ground: chatix.chatBackground,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x3,
                    vertical: AppSpacing.x1,
                  ),
                  decoration: BoxDecoration(
                    color: chatix.dateChip,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  child: Text(
                    l10n.appearancePreview,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: chatix.bubbleIncomingForeground,
                    ),
                  ),
                ),
              ),
              SizedBox(height: chatix.density.groupGap),
              _PreviewBubble(text: l10n.previewIncomingMessage),
              SizedBox(height: chatix.density.groupGap),
              _PreviewBubble(
                text: l10n.previewOutgoingMessage,
                isOutgoing: true,
              ),
              SizedBox(height: chatix.density.groupGap),
              _PreviewBubble(text: l10n.previewIncomingReply),
              SizedBox(height: chatix.density.stackGap),
              const _TypingBubble(),
            ],
          ),
        ),
      ),
    );
  }
}

/// One bubble, cut and filled exactly as the chat cuts and fills it.
class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.text, this.isOutgoing = false});

  final String text;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final chatix = ChatixTheme.of(context);
    final density = chatix.density;

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: ChatixTheme.duration,
        curve: ChatixTheme.curve,
        padding: EdgeInsets.symmetric(
          horizontal: density.bubblePaddingX,
          vertical: density.bubblePaddingY,
        ),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: ShapeDecoration(
          gradient: isOutgoing ? chatix.bubbleOutgoingGradient : null,
          color: isOutgoing ? null : chatix.bubbleIncoming,
          shape: BubbleShape.of(
            context,
            isOutgoing: isOutgoing,
            side: isOutgoing
                ? BorderSide.none
                : BorderSide(color: chatix.bubbleIncomingBorder),
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isOutgoing
                ? chatix.bubbleOutgoingForeground
                : chatix.bubbleIncomingForeground,
          ),
        ),
      ),
    );
  }
}

/// The live half of the preview: someone is always writing.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final chatix = ChatixTheme.of(context);
    final density = chatix.density;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: density.bubblePaddingX,
          vertical: density.bubblePaddingY + 2,
        ),
        decoration: ShapeDecoration(
          color: chatix.bubbleIncoming,
          shape: BubbleShape.of(
            context,
            isOutgoing: false,
            isFirstInGroup: false,
            side: BorderSide(color: chatix.bubbleIncomingBorder),
          ),
        ),
        child: TypingDots(color: chatix.bubbleIncomingForeground),
      ),
    );
  }
}
