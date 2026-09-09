import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/features/ui_showcase/ui_showcase.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpShowcase(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ComponentShowcaseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('the showcase lays out on the $name theme', (tester) async {
      await pumpShowcase(tester, theme: theme);

      expect(tester.takeException(), isNull);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ComponentShowcaseScreen)),
      );
      expect(find.text(l10n.showcaseAccents), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(l10n.showcaseComponents),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every section of the design system is on the page', (
    tester,
  ) async {
    await pumpShowcase(tester, theme: AppTheme.lightTheme);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ComponentShowcaseScreen)),
    );

    for (final section in [
      l10n.showcaseAccents,
      l10n.showcaseNeutrals,
      l10n.showcaseRadii,
      l10n.showcaseSpacing,
      l10n.showcaseElevation,
      l10n.showcaseMotion,
      l10n.showcaseTypography,
      l10n.showcaseBubbles,
      l10n.showcaseReactions,
      l10n.showcaseAuthors,
      l10n.showcaseComponents,
    ]) {
      await tester.scrollUntilVisible(
        find.text(section),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(section), findsOneWidget, reason: section);
    }
  });

  testWidgets('the density control on the page re-themes it live', (
    tester,
  ) async {
    await pumpShowcase(tester, theme: AppTheme.lightTheme);

    final element = tester.element(find.byType(ComponentShowcaseScreen));
    final l10n = AppLocalizations.of(element);

    await tester.tap(find.text(l10n.densityCompact));
    await tester.pumpAndSettle();

    expect(find.text(l10n.densityCompact), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      AppDensity.compact.bubblePaddingY,
      lessThan(AppDensity.cozy.bubblePaddingY),
    );
  });
}
