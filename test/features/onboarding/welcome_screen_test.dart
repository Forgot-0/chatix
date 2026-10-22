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

  testWidgets('opens on the first slide with a way past it', (tester) async {
    await pumpWelcome(tester);

    expect(find.text(l10n.onboardingRealtimeTitle), findsOneWidget);
    expect(find.text(l10n.onboardingSkip), findsOneWidget);
    expect(find.text(l10n.onboardingNext), findsOneWidget);
    expect(find.text(l10n.welcomeSignIn), findsOneWidget);
  });

  testWidgets('walks through the three slides and ends at registration', (
    tester,
  ) async {
    await pumpWelcome(tester);

    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingTogetherTitle), findsOneWidget);

    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingPrivacyTitle), findsOneWidget);

    // The last slide has nothing left to skip, and the button says so.
    expect(find.text(l10n.onboardingNext), findsNothing);
    expect(
      tester
          .widget<Visibility>(
            find.ancestor(
              of: find.text(l10n.onboardingSkip),
              matching: find.byType(Visibility),
            ),
          )
          .visible,
      isFalse,
    );

    await tester.tap(find.text(l10n.welcomeGetStarted));
    await tester.pumpAndSettle();

    expect(find.text('register screen'), findsOneWidget);
    // Seen once is seen for good: the splash redirect reads this flag.
    expect(store.hasSeenOnboarding, isTrue);
  });

  testWidgets('a swipe pages too', (tester) async {
    await pumpWelcome(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text(l10n.onboardingTogetherTitle), findsOneWidget);
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

  group('on a desktop window', () {
    Future<void> pumpWide(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpWelcome(tester);
    }

    testWidgets('everything is on one page, with nothing to skip', (
      tester,
    ) async {
      await pumpWide(tester);

      expect(find.text(l10n.welcomeHeadline), findsOneWidget);
      expect(find.text(l10n.onboardingRealtimeTitle), findsOneWidget);
      expect(find.text(l10n.onboardingTogetherTitle), findsOneWidget);
      expect(find.text(l10n.onboardingPrivacyTitle), findsOneWidget);
      expect(find.text(l10n.onboardingSkip), findsNothing);
      expect(find.text(l10n.onboardingNext), findsNothing);
    });

    testWidgets('"Get started" goes to registration', (tester) async {
      await pumpWide(tester);

      await tester.tap(find.text(l10n.welcomeGetStarted));
      await tester.pumpAndSettle();

      expect(find.text('register screen'), findsOneWidget);
      expect(store.hasSeenOnboarding, isTrue);
    });

    testWidgets('and sign-in is one click away', (tester) async {
      await pumpWide(tester);

      await tester.tap(find.text(l10n.welcomeSignIn));
      await tester.pumpAndSettle();

      expect(find.text('sign in screen'), findsOneWidget);
    });
  });
}
