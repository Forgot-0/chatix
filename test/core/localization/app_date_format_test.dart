import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

void main() {
  // What `GlobalMaterialLocalizations` does for the app when a locale loads.
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ru');
    await initializeDateFormatting('ja');
  });

  // A Saturday in October: six days back is a Sunday, and last year's dates
  // are a calendar away.
  final now = DateTime(2026, 10, 10, 14, 30);

  AppDateFormat ru({bool use24 = false}) => AppDateFormat(
    locale: 'ru',
    l10n: AppLocalizationsRu(),
    use24HourClock: use24,
    now: now,
  );

  AppDateFormat en({bool use24 = false}) => AppDateFormat(
    locale: 'en',
    l10n: AppLocalizationsEn(),
    use24HourClock: use24,
    now: now,
  );

  group('the time of day', () {
    test('Russian writes a 24-hour clock with a leading zero', () {
      expect(ru().time(DateTime(2026, 10, 10, 9, 2)), '09:02');
      expect(ru().time(DateTime(2026, 10, 10, 21, 40)), '21:40');
      expect(ru().time(DateTime(2026, 10, 10, 0, 5)), '00:05');
    });

    test('English writes a 12-hour clock, with a plain space before AM', () {
      expect(en().time(DateTime(2026, 10, 10, 9, 2)), '9:02 AM');
      expect(en().time(DateTime(2026, 10, 10, 21, 40)), '9:40 PM');
      expect(en().time(DateTime(2026, 10, 10, 9, 2)), isNot(contains(' ')));
    });

    test('a device set to 24-hour time wins over the locale', () {
      expect(en(use24: true).time(DateTime(2026, 10, 10, 9, 2)), '09:02');
      expect(ru(use24: true).time(DateTime(2026, 10, 10, 9, 2)), '09:02');
    });

    test('a UTC stamp is shown in local time', () {
      final utc = DateTime.utc(2026, 10, 10, 6, 2);
      expect(ru().time(utc), ru().time(utc.toLocal()));
    });
  });

  group('the day chip', () {
    test('today and yesterday are words', () {
      expect(ru().day(DateTime(2026, 10, 10, 0, 1)), 'Сегодня');
      expect(ru().day(DateTime(2026, 10, 9, 23, 59)), 'Вчера');
      expect(en().day(DateTime(2026, 10, 10, 8)), 'Today');
      expect(en().day(DateTime(2026, 10, 9, 8)), 'Yesterday');
    });

    test('earlier this year is a day and a month, no year', () {
      expect(ru().day(DateTime(2026, 3, 2, 12)), '2 марта');
      expect(en().day(DateTime(2026, 3, 2, 12)), 'March 2');
    });

    test('another year names it, without the "г." of a document', () {
      expect(ru().day(DateTime(2025, 3, 2, 12)), '2 марта 2025');
      expect(en().day(DateTime(2025, 3, 2, 12)), 'March 2, 2025');
    });

    test('date leaves out the shortcuts', () {
      expect(ru().date(DateTime(2026, 10, 10, 9)), '10 октября');
      expect(en().date(DateTime(2026, 10, 9, 9)), 'October 9');
    });
  });

  group('the chat list stamp', () {
    test('today is the same clock the bubble shows', () {
      final at = DateTime(2026, 10, 10, 9, 37);
      expect(ru().listStamp(at), ru().time(at));
      expect(ru().listStamp(at), '09:37');
      expect(en().listStamp(at), '9:37 AM');
    });

    test('a stamp a few minutes ahead is still today', () {
      expect(ru().listStamp(DateTime(2026, 10, 10, 14, 32)), '14:32');
      expect(ru().listStamp(DateTime(2026, 10, 11, 0, 1)), '00:01');
    });

    test('yesterday is a word', () {
      expect(ru().listStamp(DateTime(2026, 10, 9, 23, 59)), 'Вчера');
      expect(en().listStamp(DateTime(2026, 10, 9, 0, 1)), 'Yesterday');
    });

    test('the rest of the week is a capitalised weekday', () {
      expect(ru().listStamp(DateTime(2026, 10, 4, 12)), 'Вс');
      expect(ru().listStamp(DateTime(2026, 10, 7, 12)), 'Ср');
      expect(en().listStamp(DateTime(2026, 10, 4, 12)), 'Sun');
    });

    test('the weekday follows the locale', () {
      final ja = AppDateFormat(
        locale: 'ja',
        l10n: AppLocalizationsEn(),
        now: now,
      );
      expect(ja.listStamp(DateTime(2026, 10, 5, 12)), '月');
    });

    test('six days back is still a weekday, seven is a date', () {
      expect(ru().listStamp(DateTime(2026, 10, 4, 0, 1)), 'Вс');
      expect(ru().listStamp(DateTime(2026, 10, 3, 23, 59)), '03.10.26');
      expect(ru().listStamp(DateTime(2025, 3, 2, 12)), '02.03.25');
    });

    test('a locale with no date symbols falls back to English', () {
      final unknown = AppDateFormat(
        locale: 'xx',
        l10n: AppLocalizationsEn(),
        now: now,
      );
      expect(unknown.listStamp(DateTime(2026, 10, 4, 12)), 'Sun');
      expect(unknown.time(DateTime(2026, 10, 10, 9, 2)), '9:02 AM');
    });
  });

  group('the full date and time', () {
    test('Russian opens with a capital and drops the "г."', () {
      expect(
        ru().fullDateTime(DateTime(2025, 3, 2, 9, 2)),
        'Воскресенье, 2 марта 2025, 09:02',
      );
    });

    test('English keeps its own order', () {
      expect(
        en().fullDateTime(DateTime(2025, 3, 2, 9, 2)),
        'Sunday, March 2, 2025, 9:02 AM',
      );
    });
  });

  group('a birthday', () {
    test('Russian: day, month and year, no weekday, the age in brackets', () {
      expect(
        ru().birthday(day: 12, month: 4, year: 1990),
        '12 апреля 1990 (36 лет)',
      );
    });

    test('the age agrees with its number in Russian', () {
      // 1, 2–4 and 5+ are three different words ("год", "года", "лет").
      expect(
        ru().birthday(day: 1, month: 1, year: 2025),
        '1 января 2025 (1 год)',
      );
      expect(
        ru().birthday(day: 1, month: 1, year: 2023),
        '1 января 2023 (3 года)',
      );
      expect(
        ru().birthday(day: 1, month: 1, year: 2005),
        '1 января 2005 (21 год)',
      );
      expect(
        ru().birthday(day: 1, month: 1, year: 2014),
        '1 января 2014 (12 лет)',
      );
    });

    test('English keeps its own order and says "years old"', () {
      expect(
        en().birthday(day: 12, month: 4, year: 1990),
        'April 12, 1990 (36 years old)',
      );
      expect(
        en().birthday(day: 1, month: 1, year: 2025),
        'January 1, 2025 (1 year old)',
      );
    });

    test('without a year it is the day and month alone, and no age', () {
      expect(ru().birthday(day: 12, month: 4), '12 апреля');
      expect(en().birthday(day: 12, month: 4), 'April 12');
      // A leap day with no year still has a day to stand on.
      expect(ru().birthday(day: 29, month: 2), '29 февраля');
    });

    test('a date in the future is shown, without a negative age', () {
      expect(ru().birthday(day: 1, month: 1, year: 2030), '1 января 2030');
    });

    test('a year is not counted until its day comes round', () {
      final today = DateTime(2026, 10, 10);
      expect(AppDateFormat.ageOn(today, day: 10, month: 10, year: 1990), 36);
      expect(AppDateFormat.ageOn(today, day: 11, month: 10, year: 1990), 35);
      expect(AppDateFormat.ageOn(today, day: 9, month: 10, year: 1990), 36);
      expect(AppDateFormat.ageOn(today, day: 1, month: 11, year: 1990), 35);
    });

    test('29 February comes of age on 1 March in a common year', () {
      expect(
        AppDateFormat.ageOn(
          DateTime(2027, 2, 28),
          day: 29,
          month: 2,
          year: 2008,
        ),
        18,
      );
      expect(
        AppDateFormat.ageOn(
          DateTime(2027, 3, 1),
          day: 29,
          month: 2,
          year: 2008,
        ),
        19,
      );
    });
  });

  group('from a context', () {
    Future<AppDateFormat> formatIn(
      WidgetTester tester, {
      required Locale locale,
      bool use24 = false,
      DateTime? clock,
    }) async {
      late AppDateFormat format;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(alwaysUse24HourFormat: use24),
            child: Builder(
              builder: (context) {
                format = AppDateFormat.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
          builder: clock == null
              ? null
              : (context, child) => AppClock(now: clock, child: child!),
        ),
      );
      return format;
    }

    testWidgets('takes the language and the 24-hour switch', (tester) async {
      final format = await formatIn(
        tester,
        locale: const Locale('en'),
        use24: true,
      );
      expect(format.time(DateTime(2026, 10, 10, 9, 2)), '09:02');
      expect(format.l10n.dateToday, 'Today');
    });

    testWidgets('an AppClock above pins what "today" is', (tester) async {
      final format = await formatIn(
        tester,
        locale: const Locale('ru'),
        clock: DateTime(2025, 3, 3, 12),
      );
      expect(format.day(DateTime(2025, 3, 2, 18)), 'Вчера');
      expect(format.day(DateTime(2024, 3, 2, 18)), '2 марта 2024');
    });
  });
}
