import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/notification/presentation/utils/notification_timestamp.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

void main() {
  final now = DateTime(2026, 9, 17, 12);

  /// Renders the helper inside a real localisation scope, because that is the
  /// only place `MaterialLocalizations` exists.
  Future<String> format(WidgetTester tester, DateTime timestamp) async {
    late String result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = formatNotificationTimestamp(
              timestamp,
              AppLocalizations.of(context),
              MaterialLocalizations.of(context),
              now: now,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    return result;
  }

  testWidgets('anything under a minute old is "just now"', (tester) async {
    expect(
      await format(tester, now.subtract(const Duration(seconds: 59))),
      'Just now',
    );
  });

  testWidgets('a clock running ahead of the server is not a countdown', (
    tester,
  ) async {
    expect(
      await format(tester, now.add(const Duration(minutes: 5))),
      'Just now',
    );
  });

  testWidgets('rounds down rather than up', (tester) async {
    expect(
      await format(tester, now.subtract(const Duration(minutes: 1, seconds: 59))),
      '1 min ago',
    );
  });

  testWidgets('minutes, then hours, then days', (tester) async {
    expect(
      await format(tester, now.subtract(const Duration(minutes: 5))),
      '5 min ago',
    );
    expect(
      await format(tester, now.subtract(const Duration(hours: 3))),
      '3 hr ago',
    );
    expect(
      await format(tester, now.subtract(const Duration(days: 1))),
      'Yesterday',
    );
    expect(
      await format(tester, now.subtract(const Duration(days: 3))),
      '3 days ago',
    );
  });

  testWidgets('older than a week is a date, not a count', (tester) async {
    final result = await format(tester, now.subtract(const Duration(days: 40)));

    expect(result, isNot(contains('ago')));
    expect(result, contains('Aug'));
  });
}
