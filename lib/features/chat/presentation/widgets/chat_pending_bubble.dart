import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A message the queue is carrying, drawn where it will land.
///
/// It has no seq and no server timestamp yet, so it cannot be grouped, dated
/// or read-marked like a real one — it sits at the bottom under a sending
/// tick until the send is answered. Three states, because they mean three
/// different things to whoever is looking at it: going out, waiting for
/// another try, and stopped until you say what to do with it.
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
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(chatDetailProvider(chatId).notifier);

    final stuck = pending.needsAttention;
    final waiting = !stuck && pending.attempts > 0;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: stuck ? Border.all(color: theme.colorScheme.error) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (pending.content != null) Text(pending.content!),
            if (pending.uploadTokens.isNotEmpty)
              Text(
                l10n.attachmentsCount(pending.uploadTokens.length),
                style: theme.textTheme.labelSmall,
              ),
            const SizedBox(height: 4),
            if (stuck)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      pending.failureMessage ?? l10n.messageNotSent,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => notifier.retry(pending),
                    child: Text(l10n.retry),
                  ),
                  TextButton(
                    onPressed: () => notifier.discard(pending),
                    child: Text(l10n.discard),
                  ),
                ],
              )
            else if (waiting)
              // Still ours to send, just not right now. Saying so is what
              // keeps a queued message from reading as a lost one.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.messageWaitingToSend,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else
              const StatusTicks(status: MessageDeliveryStatus.sending),
          ],
        ),
      ),
    );
  }
}
