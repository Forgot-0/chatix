import 'package:chatix/core/storage/local_storage_service.dart';

/// Whether this device asks for a fingerprint or a face when ChatiX is
/// reopened.
///
/// A device setting, not an account one: it protects the copy of the chats
/// that is already on this phone, so it lives beside the other local
/// preferences rather than on the server. Read synchronously because the
/// lock has to be up before the first frame, not one frame later.
abstract interface class AppLockStore {
  bool get isBiometricUnlockEnabled;

  Future<void> setBiometricUnlockEnabled(bool enabled);
}

class SharedPrefsAppLockStore implements AppLockStore {
  SharedPrefsAppLockStore(this._storage);

  static const String storageKey = 'biometric_unlock_enabled';

  final LocalStorageService _storage;

  @override
  bool get isBiometricUnlockEnabled => _storage.getBool(storageKey) ?? false;

  @override
  Future<void> setBiometricUnlockEnabled(bool enabled) async {
    if (enabled) {
      await _storage.setBool(storageKey, true);
      return;
    }
    await _storage.remove(storageKey);
  }
}

class InMemoryAppLockStore implements AppLockStore {
  InMemoryAppLockStore({bool enabled = false}) : _enabled = enabled;

  bool _enabled;

  @override
  bool get isBiometricUnlockEnabled => _enabled;

  @override
  Future<void> setBiometricUnlockEnabled(bool enabled) async =>
      _enabled = enabled;
}
