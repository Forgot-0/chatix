import 'package:chatix/core/storage/local_storage_service.dart';

/// Whether this device has already been walked through the welcome pages.
///
/// A single device-local bit: nothing about it belongs to the account, and
/// signing out on a phone that has already seen the tour should not show it
/// again. Reads are synchronous because the router's redirect runs before
/// the first frame and cannot await anything.
abstract interface class OnboardingStore {
  bool get hasSeenOnboarding;

  Future<void> markOnboardingSeen();

  /// Puts the tour back, for a device that has just been signed out of and
  /// wiped.
  Future<void> forgetOnboarding();
}

class SharedPrefsOnboardingStore implements OnboardingStore {
  SharedPrefsOnboardingStore(this._storage);

  static const String storageKey = 'onboarding_seen';

  final LocalStorageService _storage;

  @override
  bool get hasSeenOnboarding => _storage.getBool(storageKey) ?? false;

  @override
  Future<void> markOnboardingSeen() => _storage.setBool(storageKey, true);

  @override
  Future<void> forgetOnboarding() => _storage.remove(storageKey);
}

/// The fallback for a run with no shared preferences behind it — a widget
/// test, mostly. The tour is then shown once per app run rather than never.
class InMemoryOnboardingStore implements OnboardingStore {
  InMemoryOnboardingStore({bool seen = false}) : _seen = seen;

  bool _seen;

  @override
  bool get hasSeenOnboarding => _seen;

  @override
  Future<void> markOnboardingSeen() async => _seen = true;

  @override
  Future<void> forgetOnboarding() async => _seen = false;
}
