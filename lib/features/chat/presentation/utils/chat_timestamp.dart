import 'package:intl/intl.dart';

import 'package:chatix/gen/l10n/app_localizations.dart';

/// The stamp on a chat row: precise while it still matters, coarse once it
/// does not.
///
/// Today is a time, yesterday is a word, the rest of the week is a weekday and
/// anything older is a date. Everything but "Yesterday" comes out of `intl` in
/// [locale], so a Japanese reader gets Japanese weekdays without a second
/// table to keep in step.
String formatChatTimestamp(
  DateTime value,
  AppLocalizations l10n, {
  required String locale,
  DateTime? now,
}) {
  final at = value.toLocal();
  final today = _startOfDay(now?.toLocal() ?? DateTime.now());
  final day = _startOfDay(at);

  final daysApart = today.difference(day).inDays;
  final tag = _safeLocale(locale);

  // A stamp in the future is a clock that disagrees with the server, not a
  // scheduled message: show it as now rather than as a date.
  if (daysApart <= 0) return DateFormat.Hm(tag).format(at);
  if (daysApart == 1) return l10n.dateYesterday;
  if (daysApart < 7) return DateFormat.E(tag).format(at);

  return DateFormat('dd.MM.yy', tag).format(at);
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Date symbols are loaded per locale by `GlobalMaterialLocalizations`. In a
/// harness that skipped those delegates the locale is simply unknown, and
/// asking `intl` for it would throw mid-build — English is a better row than
/// no row.
String _safeLocale(String locale) =>
    DateFormat.localeExists(locale) ? locale : 'en';
