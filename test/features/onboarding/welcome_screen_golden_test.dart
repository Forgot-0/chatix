import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/brand/chatix_logo.dart';
import 'package:chatix/features/onboarding/data/datasources/onboarding_store.dart';
import 'package:chatix/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:chatix/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The first thing a new install shows: the mark, then the words.
///
/// Like sign-in, the welcome lives outside the app shell, so the desktop
/// golden is the whole window.
void main() {
  const phone = Size(390, 844);
  const desktop = Size(1440, 900);

  Future<void> pumpWelcome(
    WidgetTester tester, {
    Size size = phone,
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
    // Let the entrance — the mark growing in, the words after it — finish.
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the logo', (tester) async {
    await pumpWelcome(tester);

    expect(find.byType(ChatixLogo), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
  });

  group('goldens', () {
    for (final window in {'phone': phone, 'desktop': desktop}.entries) {
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
  });
}
