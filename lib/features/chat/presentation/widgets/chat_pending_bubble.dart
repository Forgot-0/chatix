import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/bubble_shape.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed_metrics.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A message the queue is carrying, drawn where it will land.
///
/// It has no seq and no server timestamp yet, so it cannot be grouped, dated
/// or read-marked like a real one — it sits at the bottom under a sending
/// tick until the send is answered. Three states, because they mean three
/// different things to whoever is looking at it: going out, waiting for
/// another try, and stopped until you say what to do with it.
///
/// It is drawn as the outgoing bubble it is about to become — the same
/// shape, ground, padding, type and width limit, all read off the same feed
/// — so the server's copy replaces it without the text reflowing.
class ChatPendingBubble extends ConsumerWidget {
  const ChatPendingBubble({
    super.key,
    required this.pending,
    required this.chatId,
  });

  final PendingMessage pending;
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final density = chatix.density;
    final l10n = AppLocalizations.of(context);

    final foreground = chatix.bubbleOutgoingForeground;
    final muted = chatix.bubbleOutgoingMuted;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: muted);

    final stuck = pending.needsAttention;
    final waiting = !stuck && pending.attempts > 0;
    final content = pending.content;

    // Read when tapped, not while building: a bubble on its way out has no
    // business standing up the whole chat controller just to be drawn.
    ChatDetailController notifier() =>
        ref.read(chatDetailProvider(chatId).notifier);

    final buttonStyle = TextButton.styleFrom(
      foregroundColor: foreground,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        // The margins of a sent bubble that opens a run.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.x3,
          density.groupGap,
          AppSpacing.x3,
          0,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: density.bubblePaddingX,
            vertical: density.bubblePaddingY,
          ),
          constraints: BoxConstraints(
            maxWidth: ChatFeedMetrics.of(context).bubbleMaxWidth,
          ),
          decoration: ShapeDecoration(
            gradient: chatix.bubbleOutgoingGradient,
            shape: BubbleShape.of(
              context,
              isOutgoing: true,
              // A stopped send is ringed in the danger colour: the bubble
              // itself is the thing that needs a decision.
              side: stuck
                  ? BorderSide(color: chatix.danger, width: 1.5)
                  : BorderSide.none,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (content != null && content.isNotEmpty)
                Text(
                  content,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: foreground) ??
                      TextStyle(color: foreground),
                ),
              if (pending.uploadTokens.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_file_rounded, size: 14, color: muted),
                    const SizedBox(width: AppSpacing.x1),
                    Text(
                      l10n.attachmentsCount(pending.uploadTokens.length),
                      style: labelStyle,
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: switch ((stuck, waiting)) {
                  (true, _) => Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.x1,
                    children: [
                      Icon(Icons.error_outline, size: 14, color: foreground),
                      Text(
                        pending.failureMessage ?? l10n.messageNotSent,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                      TextButton(
                        onPressed: () => notifier().retry(pending),
                        style: buttonStyle,
                        child: Text(l10n.retry),
                      ),
                      TextButton(
                        onPressed: () => notifier().discard(pending),
                        style: buttonStyle,
                        child: Text(l10n.discard),
                      ),
                    ],
                  ),
                  // Still ours to send, just not right now. Saying so is
                  // what keeps a queued message from reading as a lost one.
                  (false, true) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14, color: muted),
                      const SizedBox(width: AppSpacing.x1),
                      Text(l10n.messageWaitingToSend, style: labelStyle),
                    ],
                  ),
                  (false, false) => StatusTicks(
                    status: MessageDeliveryStatus.sending,
                    color: muted,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
