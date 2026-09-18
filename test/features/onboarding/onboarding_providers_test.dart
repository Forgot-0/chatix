import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/router/app_router.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/onboarding/data/datasources/onboarding_store.dart';
import 'package:chatix/features/onboarding/presentation/providers/onboarding_providers.dart';

void main() {
  ProviderContainer makeContainer({bool seen = false}) {
    final container = ProviderContainer(
      overrides: [
        onboardingStoreProvider.overrideWithValue(
          InMemoryOnboardingStore(seen: seen),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('onboarding flag', () {
    test('a fresh device has not seen the tour', () {
      expect(makeContainer().read(onboardingSeenProvider), isFalse);
    });

    test('marking it seen sticks, in state and in the store', () async {
      final container = makeContainer();

      await container.read(onboardingSeenProvider.notifier).markSeen();

      expect(container.read(onboardingSeenProvider), isTrue);
      expect(
        container.read(onboardingStoreProvider).hasSeenOnboarding,
        isTrue,
      );
    });

    test('marking it seen twice is not an error', () async {
      final container = makeContainer(seen: true);

      await container.read(onboardingSeenProvider.notifier).markSeen();

      expect(container.read(onboardingSeenProvider), isTrue);
    });
  });

  group('routing around the tour', () {
    test('the welcome route is reachable without a session', () {
      expect(isPublicLocation(WelcomeRoute.location), isTrue);
    });

    test('a signed-out visitor is left on it', () {
      expect(
        resolveAuthRedirect(
          location: WelcomeRoute.path,
          isSessionUnresolved: false,
          isAuthenticated: false,
        ),
        isNull,
      );
    });

    test('a signed-in visitor is bounced off it', () {
      expect(
        resolveAuthRedirect(
          location: WelcomeRoute.path,
          isSessionUnresolved: false,
          isAuthenticated: true,
        ),
        ChatsRoute.location,
      );
    });

    test('nothing is decided while the session is still loading', () {
      expect(
        resolveAuthRedirect(
          location: WelcomeRoute.path,
          isSessionUnresolved: true,
          isAuthenticated: false,
        ),
        isNull,
      );
    });
  });
}
