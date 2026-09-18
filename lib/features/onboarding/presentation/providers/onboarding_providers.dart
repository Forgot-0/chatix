import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/onboarding/data/datasources/onboarding_store.dart';

/// Where the "this device has seen the tour" bit lives.
///
/// Falls back to memory where shared preferences were never wired up, the
/// same way the chat's own local stores do: the welcome pages are not worth
/// taking a screen down for.
final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  try {
    return SharedPrefsOnboardingStore(ref.watch(localStorageServiceProvider));
  } catch (error) {
    Logger.debug('Onboarding: no persistent storage, keeping the flag in memory');
    return InMemoryOnboardingStore();
  }
});

/// Read by the splash redirect, so it has to answer synchronously.
class OnboardingSeenController extends Notifier<bool> {
  @override
  bool build() => ref.watch(onboardingStoreProvider).hasSeenOnboarding;

  Future<void> markSeen() async {
    if (state) return;
    await ref.read(onboardingStoreProvider).markOnboardingSeen();
    state = true;
  }

  Future<void> reset() async {
    await ref.read(onboardingStoreProvider).forgetOnboarding();
    state = false;
  }
}

final onboardingSeenProvider =
    NotifierProvider<OnboardingSeenController, bool>(
      OnboardingSeenController.new,
    );
