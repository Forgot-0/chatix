import 'package:flutter/material.dart';
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

/// The clock on a bubble: the time of day, in the reader's convention.
///
/// A hardcoded `HH:mm` is wrong in every locale that writes a 12-hour clock,
/// and wrong again for the reader who has asked their phone for 24-hour time
/// in a locale that does not use it. `MaterialLocalizations` is the only
/// thing that knows both, so the pattern comes from there rather than from
/// string padding — the same call the details sheet already makes.
String formatMessageClock(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(value.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
