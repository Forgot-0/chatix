import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The way back from a jump into history to the live end of the chat.
class ChatBackToLatestBar extends StatelessWidget {
  const ChatBackToLatestBar({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_downward,
                size: 16,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).backToLatest,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the header says while people are typing.
///
/// One name when we can resolve it from the roster, a count otherwise —
/// never a bare "someone", which reads as a bug when it is the only line.
class ChatConnectionBanner extends ConsumerWidget {
  const ChatConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(chatSocketStatusProvider).value ??
        ref.read(chatSocketServiceProvider).status;

    final theme = Theme.of(context);

    final (String message, Color background, bool spinner) = switch (status) {
      ChatSocketStatus.ready ||
      ChatSocketStatus.connecting => ('', Colors.transparent, false),

      ChatSocketStatus.reconnecting => (
        'Reconnecting…',
        theme.colorScheme.secondaryContainer,
        true,
      ),

      ChatSocketStatus.disconnected => (
        'Offline — pull to refresh',
        theme.colorScheme.errorContainer,
        false,
      ),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: message.isEmpty
          ? const SizedBox(width: double.infinity, height: 0)
          : Container(
              width: double.infinity,
              color: background,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (spinner)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 14,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall,
                    semanticsLabel: message,
                  ),
                ],
              ),
            ),
    );
  }
}

/// The gateway refused our subscribe (`ws.error` / NOT_CHAT_MEMBER, §6.4).
/// The history already loaded stays readable, but nothing new will arrive, and
/// silently freezing is worse than saying so.
class ChatRealtimeRejectedBanner extends StatelessWidget {
  const ChatRealtimeRejectedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sync_problem_outlined,
            size: 14,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppLocalizations.of(context).realtimeRejected,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatReplyBanner extends StatelessWidget {
  const ChatReplyBanner({
    super.key,
    required this.message,
    required this.onCancel,
  });

  final MessageEntity message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content ?? 'Attachment',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class ChatEditBanner extends StatelessWidget {
  const ChatEditBanner({
    super.key,
    required this.message,
    required this.onCancel,
  });

  final MessageEntity message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.editingMessage,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  message.content ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
