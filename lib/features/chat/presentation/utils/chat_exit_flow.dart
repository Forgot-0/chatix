import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/search_history_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The two ways out of a chat.
enum ChatExit {
  /// `POST /chats/{id}/leave/`: the chat goes on without the reader.
  leave,

  /// `DELETE /chats/{id}/`: the chat is gone for everybody.
  delete,
}

/// "Leave group", "Delete channel"… — named after what is being left.
String chatExitLabel(ChatExit exit, ChatType type, AppLocalizations l10n) {
  final isGroup = type == ChatType.group || type == ChatType.supergroup;
  final isChannel = type == ChatType.channel;

  return switch (exit) {
    ChatExit.leave =>
      isGroup
          ? l10n.leaveGroup
          : isChannel
          ? l10n.leaveChannel
          : l10n.leaveChat,
    ChatExit.delete =>
      isGroup
          ? l10n.deleteGroup
          : isChannel
          ? l10n.deleteChannel
          : l10n.deleteChat,
  };
}

/// Leaving or deleting a chat, from wherever it is offered: asked first,
/// sent once, a refusal said in the reader's words, and the reader taken
/// back to the list once the chat is no longer theirs to look at.
///
/// Which of the two to offer is [ChatExitOptions]' to decide; this only
/// carries one out.
abstract final class ChatExitFlow {
  /// Runs [exit] for [chat]. [onBusy] hears `true` once the request goes
  /// out and `false` when it is back, so a caller can hold its buttons.
  static Future<void> run(
    BuildContext context,
    WidgetRef ref, {
    required ChatEntity chat,
    required ChatExit exit,
    ValueChanged<bool>? onBusy,
  }) async {
    final l10n = AppLocalizations.of(context);
    final label = chatExitLabel(exit, chat.type, l10n);

    final confirmed = await _confirm(
      context,
      title: label,
      body: exit == ChatExit.leave
          ? l10n.leaveChatConfirm
          : l10n.deleteChatConfirm,
    );
    if (!confirmed || !context.mounted) return;

    onBusy?.call(true);
    final result = switch (exit) {
      ChatExit.leave =>
        await ref.read(leaveChatUseCaseProvider).execute(chat.id),
      ChatExit.delete =>
        await ref.read(deleteChatUseCaseProvider).execute(chat.id),
    };
    onBusy?.call(false);

    if (!context.mounted) return;

    result.match(
      (failure) => AppSnackbar.failure(
        context,
        friendlyFailureMessage(
          failure,
          l10n: l10n,
          fallback: l10n.errorOccurred,
        ),
      ),
      (_) {
        // Off the list at once rather than whenever the refresh lands, and
        // out of the recent searches it can no longer be opened from.
        final list = ref.read(chatListProvider.notifier);
        list.removeLocally(chat.id);
        ref.read(searchHistoryProvider.notifier).forgetChat(chat.id);
        unawaited(list.refresh());
        context.go(ChatsRoute.location);
      },
    );
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(title),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
