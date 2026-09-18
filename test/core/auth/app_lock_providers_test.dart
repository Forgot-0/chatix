import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/auth/app_lock_providers.dart';
import 'package:chatix/core/auth/app_lock_store.dart';

void main() {
  ProviderContainer makeContainer({bool enabled = false}) {
    final container = ProviderContainer(
      overrides: [
        appLockStoreProvider.overrideWithValue(
          InMemoryAppLockStore(enabled: enabled),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('biometric unlock setting', () {
    test('is off until it is turned on, and survives being read again', () async {
      final container = makeContainer();

      expect(container.read(biometricUnlockEnabledProvider), isFalse);

      await container
          .read(biometricUnlockEnabledProvider.notifier)
          .setEnabled(true);

      expect(container.read(biometricUnlockEnabledProvider), isTrue);
      expect(
        container.read(appLockStoreProvider).isBiometricUnlockEnabled,
        isTrue,
      );
    });
  });

  group('app lock', () {
    test('a cold start with the setting on is locked', () {
      expect(makeContainer(enabled: true).read(appLockProvider), isTrue);
    });

    test('a cold start with the setting off is not', () {
      expect(makeContainer().read(appLockProvider), isFalse);
    });

    test('a short trip away does not lock — pickers pause the app too', () {
      final container = makeContainer(enabled: true);
      final lock = container.read(appLockProvider.notifier);

      lock.unlock();
      expect(container.read(appLockProvider), isFalse);

      final left = DateTime(2026, 9, 18, 12);
      lock.noteLeftForeground(at: left);
      lock.noteReturnedToForeground(
        at: left.add(AppLockController.graceWhileAway - const Duration(seconds: 1)),
      );

      expect(container.read(appLockProvider), isFalse);
    });

    test('coming back after the grace period is reopening the app', () {
      final container = makeContainer(enabled: true);
      final lock = container.read(appLockProvider.notifier);

      lock.unlock();

      final left = DateTime(2026, 9, 18, 12);
      lock.noteLeftForeground(at: left);
      lock.noteReturnedToForeground(
        at: left.add(AppLockController.graceWhileAway),
      );

      expect(container.read(appLockProvider), isTrue);
    });

    test('with the setting off, coming back changes nothing', () {
      final container = makeContainer();
      final lock = container.read(appLockProvider.notifier);

      final left = DateTime(2026, 9, 18, 12);
      lock.noteLeftForeground(at: left);
      lock.noteReturnedToForeground(at: left.add(const Duration(hours: 3)));

      expect(container.read(appLockProvider), isFalse);
    });

    test('a resume without a matching pause never locks', () {
      final container = makeContainer(enabled: true);
      final lock = container.read(appLockProvider.notifier);

      lock.unlock();
      lock.noteReturnedToForeground(at: DateTime(2026, 9, 18, 15));

      expect(container.read(appLockProvider), isFalse);
    });

    test('turning the setting off lets the app out', () async {
      final container = makeContainer(enabled: true);
      expect(container.read(appLockProvider), isTrue);

      await container
          .read(biometricUnlockEnabledProvider.notifier)
          .setEnabled(false);

      expect(container.read(appLockProvider), isFalse);
    });
  });
}
