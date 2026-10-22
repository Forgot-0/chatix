import 'package:chatix/gen/l10n/app_localizations.dart';

/// The steps slow mode is offered in: off, then from ten seconds to an hour.
///
/// A handful of chips rather than a number field — nobody thinks of a chat
/// as "86 400 seconds" — and the API's own range (0..86400, api-docs §5.2)
/// is still what decides; every step is inside it.
abstract final class SlowModePresets {
  static const List<int> seconds = <int>[0, 10, 30, 60, 300, 900, 3600];

  /// The steps, plus [current] when it is none of them: a chat whose interval
  /// was set some other way keeps showing it, chosen, instead of losing it
  /// the moment the page opens.
  static List<int> including(int current) {
    if (current < 0 || seconds.contains(current)) return seconds;
    return [...seconds, current]..sort();
  }
}

/// A slow-mode step as its chip says it: "Off", "10 s", "5 min", "1 h".
String slowModeLabel(int seconds, AppLocalizations l10n) {
  if (seconds <= 0) return l10n.chatSlowModeOffShort;
  if (seconds % 3600 == 0) return l10n.chatSlowModeHours(seconds ~/ 3600);
  if (seconds % 60 == 0) return l10n.chatSlowModeMinutes(seconds ~/ 60);
  return l10n.chatSlowModeSecondsShort(seconds);
}
