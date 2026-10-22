import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/features/settings/presentation/screens/privacy_exceptions_screen.dart';
import 'package:chatix/features/settings/presentation/screens/privacy_rule_screen.dart';
import 'package:chatix/features/settings/presentation/widgets/privacy_people.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../helpers/pane_frame.dart';
import '../../helpers/privacy_harness.dart';

/// Settings → Privacy → one rule → its exceptions → the picker, against a
/// fake `/profiles/privacy/` (api-docs §4.14).
void main() {
  final ru = AppLocalizationsRu();

  const configured = PrivacySettings(
    rules: {
      PrivacyRule.lastSeen: PrivacyVisibility.contacts,
      PrivacyRule.photo: PrivacyVisibility.everybody,
      PrivacyRule.calls: PrivacyVisibility.nobody,
    },
    exceptions: {
      // Анна always, Борис and a stranger never.
      PrivacyRule.lastSeen: PrivacyExceptions(allow: [1], deny: [2, 77]),
    },
  );

  Finder row(String title) => find.widgetWithText(AppGroupedTile, title);

  String lastSeen(String slug) =>
      PrivacyExceptionsRoute.locationOf(PrivacyRule.lastSeen.slug, slug);

  PrivacyHarness harness() => PrivacyHarness(
    settings: configured,
    strangers: [strangerProfile(77, 'dmitry', 'Дмитрий Орлов')],
  );

  group('the privacy page', () {
    testWidgets('sums up every rule the way Telegram does', (tester) async {
      await harness().pump(tester, surface: const Size(390, 1200));

      expect(
        find.descendant(
          of: row(ru.privacyRuleLastSeen),
          matching: find.text('Мои контакты (−2, +1)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row(ru.privacyRuleCalls),
          matching: find.text(ru.privacyNobody),
        ),
        findsOneWidget,
      );
      for (final title in [
        ru.privacyRulePhoto,
        ru.privacyRuleMessages,
        ru.privacyRuleGroupInvites,
      ]) {
        expect(
          find.descendant(
            of: row(title),
            matching: find.text(ru.privacyEverybody),
          ),
          findsOneWidget,
          reason: title,
        );
      }
      // Still there: the block list and the devices.
      expect(row(ru.blockedUsersTitle), findsOneWidget);
      expect(row(ru.privacyDevices), findsOneWidget);
    });

    testWidgets('says so when the settings cannot be read, and asks again', (
      tester,
    ) async {
      final h = harness()
        ..repository.failGet = const NetworkFailure(message: 'offline');
      await h.pump(tester);

      expect(row(ru.privacyRulesLoadFailed), findsOneWidget);
      expect(row(ru.privacyRuleLastSeen), findsNothing);

      h.repository.failGet = null;
      await tester.tap(row(ru.privacyRulesLoadFailed));
      await tester.pumpAndSettle();
      expect(row(ru.privacyRuleLastSeen), findsOneWidget);
    });

    testWidgets('a rule row opens the rule', (tester) async {
      await harness().pump(tester);

      await tester.tap(row(ru.privacyRuleMessages));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyRuleScreen), findsOneWidget);
      expect(find.text(ru.privacyQuestionMessages), findsOneWidget);
    });
  });

  group('one rule', () {
    testWidgets('ticks the answer and offers the lists it makes sense of', (
      tester,
    ) async {
      await harness().pump(
        tester,
        location: PrivacyRuleRoute.locationOf(PrivacyRule.lastSeen.slug),
      );

      final ticked = find.descendant(
        of: row(ru.privacyMyContacts),
        matching: find.byIcon(Icons.check_rounded),
      );
      expect(ticked, findsOneWidget);
      // Contacts: both lists, with how many are on each.
      expect(
        find.descendant(
          of: row(ru.privacyAlwaysAllow),
          matching: find.text(ru.privacyPeopleCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row(ru.privacyNeverAllow),
          matching: find.text(ru.privacyPeopleCount(2)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a new answer is sent at once and changes the lists offered', (
      tester,
    ) async {
      final h = harness();
      await h.pump(
        tester,
        location: PrivacyRuleRoute.locationOf(PrivacyRule.lastSeen.slug),
      );

      await tester.tap(row(ru.privacyNobody));
      await tester.pumpAndSettle();

      expect(h.repository.updates.single.rules, {
        PrivacyRule.lastSeen: PrivacyVisibility.nobody,
      });
      // Nobody is let in, so only "always allow" means anything now.
      expect(row(ru.privacyAlwaysAllow), findsOneWidget);
      expect(row(ru.privacyNeverAllow), findsNothing);
    });

    testWidgets('a refusal puts the tick back and says why', (tester) async {
      final h = harness();
      await h.pump(
        tester,
        location: PrivacyRuleRoute.locationOf(PrivacyRule.photo.slug),
      );
      h.repository.failNext = const NetworkFailure(message: 'offline');

      await tester.tap(row(ru.privacyNobody));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: row(ru.privacyEverybody),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text(ru.failureNoConnection), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('an exception list', () {
    testWidgets('names people from the book, and strangers from profiles', (
      tester,
    ) async {
      await harness().pump(tester, location: lastSeen('deny'));

      expect(find.byType(PrivacyExceptionsScreen), findsOneWidget);
      expect(find.byType(PrivacyPersonRow), findsNWidgets(2));
      expect(find.text('Борис Петров'), findsOneWidget);
      expect(find.text('Дмитрий Орлов'), findsOneWidget);
      expect(find.text('@dmitry'), findsOneWidget);
    });

    testWidgets('taking somebody off sends the list without them', (
      tester,
    ) async {
      final h = harness();
      await h.pump(tester, location: lastSeen('deny'));

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(PrivacyPersonRow, 'Борис Петров'),
          matching: find.byTooltip(ru.privacyExceptionRemove),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        h.repository.updates.single.exceptions[PrivacyRule.lastSeen],
        const PrivacyExceptions(allow: [1], deny: [77]),
      );
      expect(find.text('Борис Петров'), findsNothing);
    });

    testWidgets('the picker starts from the list and saves it whole', (
      tester,
    ) async {
      final h = harness();
      await h.pump(
        tester,
        location: lastSeen('deny'),
        surface: const Size(390, 1200),
      );

      await tester.tap(row(ru.privacyExceptionsEdit));
      await tester.pumpAndSettle();
      // Both people already on the list are picked.
      expect(find.text(ru.privacyPickerCount(2, 99)), findsOneWidget);

      // Анна is on "always allow"; picking her here moves her.
      await tester.tap(find.text('Анна Смирнова').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, ru.save));
      await tester.pumpAndSettle();

      expect(
        h.repository.updates.single.exceptions[PrivacyRule.lastSeen],
        const PrivacyExceptions(allow: [], deny: [2, 77, 1]),
      );
      // Back on the list, which now has three people on it.
      expect(find.byType(PrivacyExceptionsScreen), findsOneWidget);
      expect(find.byType(PrivacyPersonRow), findsNWidgets(3));
    });
  });

  group('goldens', () {
    final screens = {
      'rule': PrivacyRuleRoute.locationOf(PrivacyRule.lastSeen.slug),
      'exceptions': lastSeen('deny'),
    };
    for (final MapEntry(key: name, value: location) in screens.entries) {
      for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
        for (final MapEntry(key: theme, value: dark) in {
          'light': false,
          'dark': true,
        }.entries) {
          testGoldens('privacy $name, ${window.name}, $theme', (tester) async {
            await harness().pump(
              tester,
              location: location,
              window: window,
              dark: dark,
            );
            await screenMatchesGolden(
              tester,
              'privacy_${name}_${window.name}_$theme',
            );
          });
        }
      }
    }
  });
}
