import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/auth/app_lock_store.dart';
import 'package:chatix/core/auth/biometric_providers.dart';
import 'package:chatix/core/auth/biometric_service.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';

final appLockStoreProvider = Provider<AppLockStore>((ref) {
  try {
    return SharedPrefsAppLockStore(ref.watch(localStorageServiceProvider));
  } catch (error) {
    Logger.debug('App lock: no persistent storage, keeping the flag in memory');
    return InMemoryAppLockStore();
  }
});

/// Whether biometric unlock is switched on for this device.
class BiometricUnlockController extends Notifier<bool> {
  @override
  bool build() => ref.watch(appLockStoreProvider).isBiometricUnlockEnabled;

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    await ref.read(appLockStoreProvider).setBiometricUnlockEnabled(enabled);
    state = enabled;
  }
}

final biometricUnlockEnabledProvider =
    NotifierProvider<BiometricUnlockController, bool>(
      BiometricUnlockController.new,
    );

/// Whether the app is currently behind the lock screen.
///
/// Starts locked whenever the setting is on, which is what makes a cold
/// start ask — the whole point of the feature. Turning the setting off
/// unlocks in the same breath, because [build] is derived from it.
class AppLockController extends Notifier<bool> {
  @override
  bool build() => ref.watch(biometricUnlockEnabledProvider);

  /// How long the app may be away before coming back counts as reopening it.
  ///
  /// Not zero: the system camera, the file picker and the share sheet all
  /// pause the app, and locking someone out while they pick a photo to send
  /// would make the setting unusable rather than safe.
  static const Duration graceWhileAway = Duration(seconds: 30);

  DateTime? _leftAt;

  void noteLeftForeground({DateTime? at}) {
    _leftAt = at ?? DateTime.now();
  }

  /// Locks if the app was away long enough for this to be a reopening.
  void noteReturnedToForeground({DateTime? at}) {
    final left = _leftAt;
    _leftAt = null;
    if (left == null) return;
    if (!ref.read(biometricUnlockEnabledProvider)) return;

    final away = (at ?? DateTime.now()).difference(left);
    if (away >= graceWhileAway) state = true;
  }

  void unlock() => state = false;

  void lock() {
    if (!ref.read(biometricUnlockEnabledProvider)) return;
    state = true;
  }

  /// Runs the system prompt and unlocks on success.
  Future<BiometricResult> authenticate({required String reason}) async {
    final result = await ref
        .read(biometricAuthControllerProvider.notifier)
        .authenticate(reason: reason);

    if (result == BiometricResult.success) unlock();
    return result;
  }
}

final appLockProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);
