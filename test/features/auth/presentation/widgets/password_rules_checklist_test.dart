import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/presentation/widgets/password_rules_checklist.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

/// The rules under a new password tick themselves off as it is typed.
void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  Future<void> pumpChecklist(
    WidgetTester tester,
    String password, {
    double width = 400,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: PasswordRulesChecklist(password: password),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int ticks() => find.byIcon(Icons.check_circle).evaluate().length;

  testWidgets('every rule is listed before anything is typed', (tester) async {
    await pumpChecklist(tester, '');

    expect(find.text(l10n.passwordRuleLength(8, 128)), findsOneWidget);
    expect(find.text(l10n.passwordRuleUppercase), findsOneWidget);
    expect(find.text(l10n.passwordRuleLowercase), findsOneWidget);
    expect(find.text(l10n.passwordRuleDigit), findsOneWidget);
    expect(
      find.text(l10n.passwordRuleSpecial(r'!@#$%^&*(),.?":{}|<>')),
      findsOneWidget,
    );
    expect(ticks(), 0);
  });

  testWidgets('rules tick off one at a time', (tester) async {
    await pumpChecklist(tester, 'chatix');
    expect(ticks(), 1); // lowercase

    await pumpChecklist(tester, 'Chatix2026');
    expect(ticks(), 4); // + uppercase, digit, length

    await pumpChecklist(tester, 'Chatix2026!');
    expect(ticks(), 5);
  });

  testWidgets('a screen reader hears each rule and whether it is met', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpChecklist(tester, 'chatix');

    expect(find.bySemanticsLabel(l10n.passwordRuleLowercase), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(l10n.passwordRuleLowercase)),
      matchesSemantics(
        label: l10n.passwordRuleLowercase,
        value: l10n.passwordRuleMet,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(l10n.passwordRuleDigit)),
      matchesSemantics(
        label: l10n.passwordRuleDigit,
        value: l10n.passwordRuleUnmet,
      ),
    );
    semantics.dispose();
  });

  testWidgets('two columns where there is room, one where there is not', (
    tester,
  ) async {
    await pumpChecklist(tester, '', width: 400);
    final upper = tester.getTopLeft(find.text(l10n.passwordRuleUppercase));
    final length = tester.getTopLeft(
      find.text(l10n.passwordRuleLength(8, 128)),
    );
    expect(upper.dy, length.dy, reason: 'side by side');

    await pumpChecklist(tester, '', width: 260);
    final narrowUpper = tester.getTopLeft(
      find.text(l10n.passwordRuleUppercase),
    );
    final narrowLength = tester.getTopLeft(
      find.text(l10n.passwordRuleLength(8, 128)),
    );
    expect(narrowUpper.dy, greaterThan(narrowLength.dy), reason: 'stacked');
  });
}
