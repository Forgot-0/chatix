import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/widgets/forward_target_dialog.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Picking somewhere to forward a message to, and forwarding it.
///
/// One place rather than one per entry point: the bubble's menu and the
/// media viewer both forward the same way — `POST /messages/forward/` takes
/// the source chat and message and an optional comment (api-docs §5.4), and
/// what the reader happened to be looking at makes no difference.
abstract final class ForwardFlow {
  /// Asks where to send it, sends it, and says how it went.
  ///
  /// Answers true when the message was forwarded, false when the picker was
  /// dismissed or the server refused.
  static Future<bool> start(
    BuildContext context,
    WidgetRef ref, {
    required MessageEntity message,
  }) async {
    final target = await ForwardTargetDialog.pick(
      context,
      excludeChatId: message.chatId,
    );
    if (target == null || !context.mounted) return false;

    final result = await ref
        .read(forwardMessageUseCaseProvider)
        .execute(
          sourceChatId: message.chatId,
          sourceMessageId: message.id,
          targetChatId: target.chatId,
          comment: target.comment,
        );

    if (!context.mounted) return result.isRight();
    final l10n = AppLocalizations.of(context);

    return result.match(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
        return false;
      },
      (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.messageForwarded)));
        return true;
      },
    );
  }
}
