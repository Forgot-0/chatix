import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/brand/chatix_logo.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/features/onboarding/data/datasources/onboarding_store.dart';
import 'package:chatix/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:chatix/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:chatix/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The first thing a new install shows.
///
/// Like sign-in, the welcome lives outside the app shell, so every golden is
/// the whole window: the tour on a phone and a tablet, the single page on a
/// desktop.
void main() {
  const windows = {
    'phone': Size(390, 844),
    'tablet': Size(800, 1024),
    'desktop': Size(1440, 900),
  };

  Future<void> pumpWelcome(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool dark = false,
  }) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          onboardingStoreProvider.overrideWithValue(InMemoryOnboardingStore()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WelcomeScreen(),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Let the entrance — the picture growing in, the words after it —
    // finish.
    await tester.pumpAndSettle();
  }

  testWidgets('a phone pages through three illustrated slides', (tester) async {
    await pumpWelcome(tester);

    expect(find.byType(ChatixLogo), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(OnboardingDots), findsOneWidget);
    expect(tester.widget<OnboardingDots>(find.byType(OnboardingDots)).count, 3);
    expect(find.byType(AppIllustration), findsOneWidget);
  });

  testWidgets('a desktop window gets one page: picture left, buttons right', (
    tester,
  ) async {
    await pumpWelcome(tester, size: windows['desktop']!);

    expect(find.byType(PageView), findsNothing);
    expect(find.byType(OnboardingDots), findsNothing);
    expect(find.byType(OnboardingReasonRow), findsNWidgets(3));

    final picture = tester.getCenter(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppIllustration &&
            widget.kind == AppIllustrationKind.conversations,
      ),
    );
    final start = tester.getCenter(find.byType(FilledButton));
    expect(picture.dx, lessThan(720));
    expect(start.dx, greaterThan(720));
  });

  group('goldens', () {
    for (final window in windows.entries) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('welcome, ${window.key}, ${theme.key}', (tester) async {
          await pumpWelcome(tester, size: window.value, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'welcome_${window.key}_${theme.key}',
          );
        });
      }
    }

    // The last slide: "Get started" instead of "Next", and no "Skip".
    for (final theme in {'light': false, 'dark': true}.entries) {
      testGoldens('welcome, last slide, phone, ${theme.key}', (tester) async {
        await pumpWelcome(tester, dark: theme.value);

        for (var i = 0; i < 2; i++) {
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
        }

        await screenMatchesGolden(tester, 'welcome_last_phone_${theme.key}');
      });
    }
  });
}
