import 'package:chatix/gen/l10n/app_localizations.dart';

/// How long a chat can be silenced for, wherever that is asked.
///
/// The server keeps a deadline, not a switch (`notifications_muted_until`,
/// api-docs §5.2): each option is turned into a date when it is picked.
enum ChatMuteOption {
  hour(Duration(hours: 1)),
  eightHours(Duration(hours: 8)),
  twoDays(Duration(days: 2)),

  /// Until the reader turns it back on.
  forever(null);

  const ChatMuteOption(this.duration);

  /// Null for [forever].
  final Duration? duration;

  /// The deadline to send, picked at [now].
  ///
  /// Null for [forever]: "forever" is a date far enough out that nobody
  /// reaches it, and which date that is belongs to the use case that sends it.
  DateTime? untilFrom(DateTime now) {
    final span = duration;
    return span == null ? null : now.add(span);
  }

  String label(AppLocalizations l10n) => switch (this) {
    ChatMuteOption.hour => l10n.muteForHour,
    ChatMuteOption.eightHours => l10n.muteForEightHours,
    ChatMuteOption.twoDays => l10n.muteForTwoDays,
    ChatMuteOption.forever => l10n.muteForever,
  };
}
