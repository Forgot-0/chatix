import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A message the composer has handed over but the API has not confirmed.
///
/// It has no seq and no server timestamp yet, so it cannot be grouped, dated
/// or read-marked like a real one — it just sits at the bottom under a
/// sending tick until `POST /messages/` answers.
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
    final notifier = ref.read(chatDetailProvider(chatId).notifier);
    final failed = pending.failure != null;

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
          border: failed ? Border.all(color: theme.colorScheme.error) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (pending.content != null) Text(pending.content!),
            if (pending.uploadTokens.isNotEmpty)
              Text(
                AppLocalizations.of(
                  context,
                ).attachmentsCount(pending.uploadTokens.length),
                style: theme.textTheme.labelSmall,
              ),
            const SizedBox(height: 4),
            if (!failed)
              const StatusTicks(status: MessageDeliveryStatus.sending)
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      pending.failure!.message,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => notifier.retry(pending),
                    child: Text(AppLocalizations.of(context).retry),
                  ),
                  TextButton(
                    onPressed: () => notifier.discard(pending),
                    child: Text(AppLocalizations.of(context).discard),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
