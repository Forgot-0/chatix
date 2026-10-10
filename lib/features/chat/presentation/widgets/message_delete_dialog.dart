import 'package:flutter/material.dart';

import 'package:chatix/gen/l10n/app_localizations.dart';

/// The question asked before messages are deleted — one from its menu or a
/// whole selection from the bar, in the same words.
///
/// `DELETE /chats/{id}/messages/{message_id}/` takes a message away from
/// everybody in the chat (api-docs §5.4); there is no "only for me" to offer.
/// So the dialog says what will happen rather than presenting a choice the
/// server does not have.
class MessageDeleteDialog extends StatelessWidget {
  const MessageDeleteDialog({super.key, required this.count});

  /// How many messages the answer applies to.
  final int count;

  /// Asks, and answers true only for an explicit yes — dismissing the dialog
  /// is a no.
  static Future<bool> confirm(
    BuildContext context, {
    required int count,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => MessageDeleteDialog(count: count),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    // One message gets its own words rather than the plural's "one" branch:
    // in Russian that branch also answers for 21 and 31, so it has to carry
    // the number, and "Удалить 1 сообщение?" is not how anyone asks.
    final single = count == 1;

    return AlertDialog(
      title: Text(
        single ? l10n.deleteMessageTitle : l10n.deleteMessagesTitle(count),
      ),
      content: Text(
        single ? l10n.deleteMessageForEveryone : l10n.deleteMessagesForEveryone,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        // Filled in the error colour, like signing out: the one button here
        // that cannot be taken back.
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.messageDelete),
        ),
      ],
    );
  }
}
