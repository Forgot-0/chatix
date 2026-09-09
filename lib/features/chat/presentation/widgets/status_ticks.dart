import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// How far along one of your own messages is.
enum MessageDeliveryStatus {
  /// Queued locally, no `message_id` from the server yet.
  sending,

  /// The server accepted it; nobody has read it (or we cannot tell).
  sent,

  /// The other side read past it.
  read,
}

/// Which ticks — if any — belong on one of your messages.
///
/// Returns null wherever a tick would be a lie:
///
/// * on someone else's message;
/// * in a group. `messages_read` carries `{ seq, reader_id }` (api-docs §6.4)
///   and nothing about the rest of the roster, so "read" in a group of thirty
///   would mean "one unnamed person read it" — the second tick is only honest
///   in a direct chat, where there is exactly one other reader;
/// * when the peer's read position is unknown: [peerReadSeq] null means we
///   have not been told, which is not the same as "not read".
MessageDeliveryStatus? resolveDeliveryStatus({
  required bool isMine,
  required bool isDirect,
  required bool isPending,
  required int seq,
  required int? peerReadSeq,
}) {
  if (!isMine) return null;
  if (isPending) return MessageDeliveryStatus.sending;
  if (!isDirect) return null;

  final read = peerReadSeq;
  if (read != null && read >= seq) return MessageDeliveryStatus.read;
  return MessageDeliveryStatus.sent;
}

/// The clock / tick / double-tick that trails your own messages.
class StatusTicks extends StatelessWidget {
  const StatusTicks({
    super.key,
    required this.status,
    this.color,
    this.size = 14,
  });

  final MessageDeliveryStatus status;

  /// The colour for [MessageDeliveryStatus.sending] and
  /// [MessageDeliveryStatus.sent]; "read" always uses the success accent, so
  /// it stays recognisable on the outgoing gradient.
  final Color? color;

  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chatix = ChatixTheme.of(context);
    final muted = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    final (icon, tint, label) = switch (status) {
      MessageDeliveryStatus.sending => (
        Icons.access_time,
        muted,
        l10n.messageSending,
      ),
      MessageDeliveryStatus.sent => (Icons.done, muted, l10n.messageSent),
      MessageDeliveryStatus.read => (
        Icons.done_all,
        chatix.success,
        l10n.messageRead,
      ),
    };

    return Icon(icon, size: size, color: tint, semanticLabel: label);
  }
}
