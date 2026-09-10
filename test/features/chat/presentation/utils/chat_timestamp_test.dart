import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:chatix/features/chat/presentation/utils/chat_timestamp.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  // What `GlobalMaterialLocalizations` does for the app when a locale loads.
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ja');
  });

  // A Thursday, so "earlier this week" and "last week" are both reachable.
  final now = DateTime(2026, 9, 10, 14, 30);

  String format(DateTime value, {String locale = 'en'}) =>
      formatChatTimestamp(value, l10n, locale: locale, now: now);

  test('today is a time of day', () {
    expect(format(DateTime(2026, 9, 10, 9, 5)), '09:05');
  });

  test('a stamp from a few minutes ahead is still today', () {
    expect(format(DateTime(2026, 9, 10, 14, 32)), '14:32');
  });

  test('yesterday is a word', () {
    expect(format(DateTime(2026, 9, 9, 23, 59)), l10n.dateYesterday);
  });

  test('earlier this week is a weekday', () {
    expect(format(DateTime(2026, 9, 7, 12)), 'Mon');
  });

  test('the weekday follows the locale', () {
    expect(format(DateTime(2026, 9, 7, 12), locale: 'ja'), '月');
  });

  test('a week back is a date', () {
    expect(format(DateTime(2026, 9, 3, 12)), '03.09.26');
  });

  test('six days back is still a weekday, seven is not', () {
    expect(format(DateTime(2026, 9, 4, 12)), 'Fri');
    expect(format(DateTime(2026, 9, 3, 23, 59)), '03.09.26');
  });

  test('a locale with no date symbols loaded falls back to English', () {
    expect(
      formatChatTimestamp(
        DateTime(2026, 9, 7, 12),
        l10n,
        locale: 'xx',
        now: now,
      ),
      'Mon',
    );
  });
}
