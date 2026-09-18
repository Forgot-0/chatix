import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/onboarding/data/datasources/onboarding_store.dart';
import 'package:chatix/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:chatix/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  late InMemoryOnboardingStore store;

  Future<void> pumpWelcome(WidgetTester tester) async {
    store = InMemoryOnboardingStore();

    final router = GoRouter(
      initialLocation: WelcomeRoute.location,
      routes: [
        GoRoute(
          path: WelcomeRoute.path,
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: LoginRoute.path,
          builder: (context, state) =>
              const Scaffold(body: Text('sign in screen')),
        ),
        GoRoute(
          path: RegisterRoute.path,
          builder: (context, state) =>
              const Scaffold(body: Text('register screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [onboardingStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the welcome page with a way past it', (tester) async {
    await pumpWelcome(tester);

    expect(find.text(l10n.welcomeHeadline), findsOneWidget);
    expect(find.text(l10n.welcomeTagline), findsOneWidget);
    expect(find.text(l10n.onboardingSkip), findsOneWidget);
    expect(find.text(l10n.welcomeGetStarted), findsOneWidget);
  });

  testWidgets('walks through the three reasons and ends at registration', (
    tester,
  ) async {
    await pumpWelcome(tester);

    await tester.tap(find.text(l10n.welcomeGetStarted));
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingRealtimeTitle), findsOneWidget);

    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingTogetherTitle), findsOneWidget);

    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingPrivacyTitle), findsOneWidget);

    await tester.tap(find.text(l10n.onboardingDone));
    await tester.pumpAndSettle();

    expect(find.text('register screen'), findsOneWidget);
    // Seen once is seen for good: the splash redirect reads this flag.
    expect(store.hasSeenOnboarding, isTrue);
  });

  testWidgets('skipping goes to sign in and still counts as seen', (
    tester,
  ) async {
    await pumpWelcome(tester);

    await tester.tap(find.text(l10n.onboardingSkip));
    await tester.pumpAndSettle();

    expect(find.text('sign in screen'), findsOneWidget);
    expect(store.hasSeenOnboarding, isTrue);
  });

  testWidgets('the "I already have an account" way out works too', (
    tester,
  ) async {
    await pumpWelcome(tester);

    await tester.tap(find.text(l10n.welcomeSignIn));
    await tester.pumpAndSettle();

    expect(find.text('sign in screen'), findsOneWidget);
    expect(store.hasSeenOnboarding, isTrue);
  });
}
