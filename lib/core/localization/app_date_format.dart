import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:chatix/gen/l10n/app_localizations.dart';

/// Every date and time the app prints, in one voice.
///
/// The bubble, the chat list, the day chip and the details sheet used to
/// format on their own — `MaterialLocalizations` in one place, `intl` in
/// another — and disagreed: the same message read "9:02" in its bubble and
/// "09:37"-style in the list. Everything now goes through here, so a reader
/// sees one clock.
///
/// The clock follows the locale's own convention (CLDR's `j` skeleton): a
/// 24-hour clock with a leading zero where the locale writes one ("09:02" in
/// Russian or German), a 12-hour one where it does not ("9:02 AM" in
/// English). A device set to 24-hour time wins over the locale.
@immutable
class AppDateFormat {
  const AppDateFormat({
    required this.locale,
    required this.l10n,
    this.use24HourClock = false,
    DateTime? now,
  }) : _now = now;

  /// The formatter for the reader in [context]: their language, their clock.
  ///
  /// [now] pins "today"; left out, it is what an [AppClock] above says, and
  /// with none, the moment of each call.
  factory AppDateFormat.of(BuildContext context, {DateTime? now}) =>
      AppDateFormat(
        locale: Localizations.localeOf(context).toLanguageTag(),
        l10n: AppLocalizations.of(context),
        use24HourClock:
            MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false,
        now: now ?? AppClock.maybeNowOf(context),
      );

  /// A BCP 47 tag, `ru` or `en-US`.
  final String locale;

  final AppLocalizations l10n;

  /// The device asked for a 24-hour clock whatever the locale says.
  final bool use24HourClock;

  final DateTime? _now;

  /// The long form of a date with its year, where CLDR's own carries
  /// something a chat should not. Russian's ends in "г." — "2 марта 2025 г."
  /// — which reads like a document rather than a conversation.
  static const Map<String, String> _dateWithYearPatterns = <String, String>{
    'ru': 'd MMMM y',
  };

  /// The time of day: "09:02", or "9:02 AM".
  String time(DateTime value) {
    final local = value.toLocal();
    final format = use24HourClock ? DateFormat.Hm(_tag) : DateFormat.jm(_tag);

    // CLDR puts a narrow no-break space before "AM"; the bundled font has no
    // glyph for it, and nothing gains from it in a single-line stamp.
    return format.format(local).replaceAll(' ', ' ');
  }

  /// The day a stretch of conversation belongs to: "Today", "Yesterday",
  /// "2 March", and the year only when it is not this one.
  String day(DateTime value) {
    final local = value.toLocal();

    final daysAgo = _daysBetween(local, _today);
    if (daysAgo == 0) return l10n.dateToday;
    if (daysAgo == 1) return l10n.dateYesterday;

    return date(local);
  }

  /// A calendar date without the "today" shortcuts: "2 March", or
  /// "2 March 2025" from another year.
  String date(DateTime value) {
    final local = value.toLocal();

    if (local.year == _today.year) return DateFormat.MMMMd(_tag).format(local);

    final pattern = _dateWithYearPatterns[_language];
    return pattern == null
        ? DateFormat.yMMMMd(_tag).format(local)
        : DateFormat(pattern, _tag).format(local);
  }

  /// The stamp on a chat row: precise while it still matters, coarse once it
  /// does not.
  ///
  /// Today is a time, yesterday is a word, the rest of the week is a weekday
  /// — capitalised, "Sun" and "Вс" alike, because it stands alone at the end
  /// of a row — and anything older is a date.
  String listStamp(DateTime value) {
    final local = value.toLocal();

    // A stamp in the future is a clock that disagrees with the server, not a
    // scheduled message: show it as now rather than as a date.
    final daysAgo = _daysBetween(local, _today);
    if (daysAgo <= 0) return time(local);
    if (daysAgo == 1) return l10n.dateYesterday;
    if (daysAgo < 7) {
      return toBeginningOfSentenceCase(DateFormat.E(_tag).format(local), _tag);
    }

    return DateFormat('dd.MM.yy', _tag).format(local);
  }

  /// A full date and time, for a sheet that has room for it: "Sunday,
  /// March 2, 2025, 9:02 AM", "Воскресенье, 2 марта 2025, 09:02".
  String fullDateTime(DateTime value) {
    final local = value.toLocal();

    final pattern = _dateWithYearPatterns[_language];
    final date = pattern == null
        ? DateFormat.yMMMMEEEEd(_tag).format(local)
        : '${DateFormat.EEEE(_tag).format(local)}, '
              '${DateFormat(pattern, _tag).format(local)}';

    // It opens a line, and Russian weekdays are lower case.
    return '${toBeginningOfSentenceCase(date, _tag)}, ${time(local)}';
  }

  DateTime get _today {
    final now = (_now ?? DateTime.now()).toLocal();
    return DateTime(now.year, now.month, now.day);
  }

  /// Calendar days from [from] to [to], ignoring the time of day and the
  /// hour a daylight-saving switch adds or takes away.
  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Date symbols are loaded per locale by `GlobalMaterialLocalizations`. In
  /// a harness that skipped those delegates the locale is simply unknown,
  /// and asking `intl` for it would throw mid-build — English is a better
  /// stamp than none.
  String get _tag => DateFormat.localeExists(locale) ? locale : 'en';

  String get _language => _tag.split(RegExp('[-_]')).first;
}

/// What "now" is for everything below it that formats a date.
///
/// The app never places one: without it [AppDateFormat] asks the system
/// clock on every call. A preview or a golden does, so that "Yesterday", a
/// weekday or a year on a date chip reads the same whatever day it is
/// rendered on.
class AppClock extends InheritedWidget {
  const AppClock({super.key, required this.now, required super.child});

  final DateTime now;

  static DateTime? maybeNowOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppClock>()?.now;

  @override
  bool updateShouldNotify(AppClock oldWidget) => now != oldWidget.now;
}
