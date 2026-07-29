// Storage Providers
// Riverpod providers for storage-related services

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/local_storage_service.dart';
import '../storage/secure_storage_service.dart';

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

/// Provider for LocalStorageService instance
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalStorageService(prefs);
});

/// Provider for SecureStorageService instance (access_token only). Exposed
/// as the interface type so tests can override it with the in-memory fake
/// in `test/helpers/fakes/fake_secure_storage_service.dart` instead of
/// letting widget/golden tests hit the real platform channel (see
/// SecureStorageService's doc comment for why that hangs rather than fails
/// fast).
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageServiceImpl.create();
});
