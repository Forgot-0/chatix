import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chatix/core/error/exceptions.dart';

/// Secure (encrypted) key-value storage — currently just the access token.
///
/// This is an interface (not a concrete class) for the same reason
/// `AuthRepository`/`AuthRemoteDataSource` are: [SecureStorageServiceImpl]
/// wraps a real platform plugin (`flutter_secure_storage`), which talks to
/// a platform channel that simply doesn't exist in a plain `flutter test`
/// VM run — unlike most plugins it doesn't fail fast there, it hangs
/// forever. Any widget/golden test whose provider graph reaches this
/// interface MUST override it with `test/helpers/fakes/fake_secure_storage_service.dart`'s
/// in-memory fake instead of letting the real plugin run.
abstract class SecureStorageService {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
  Future<bool> containsKey({required String key});
  Future<Map<String, String>> readAll();
}

class SecureStorageServiceImpl implements SecureStorageService {
  final FlutterSecureStorage _secureStorage;

  SecureStorageServiceImpl(this._secureStorage);

  // Default constructor
  factory SecureStorageServiceImpl.create() {
    return SecureStorageServiceImpl(
      const FlutterSecureStorage(
        aOptions: AndroidOptions(
          // ignore: deprecated_member_use
          encryptedSharedPreferences: true,
        ),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      ),
    );
  }

  // Write value
  @override
  Future<void> write({required String key, required String value}) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      throw CacheException(message: 'Failed to write secure data: $e');
    }
  }

  // Read value
  @override
  Future<String?> read({required String key}) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      throw CacheException(message: 'Failed to read secure data: $e');
    }
  }

  // Delete value
  @override
  Future<void> delete({required String key}) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      throw CacheException(message: 'Failed to delete secure data: $e');
    }
  }

  // Delete all
  @override
  Future<void> deleteAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw CacheException(message: 'Failed to delete all secure data: $e');
    }
  }

  // Check if key exists
  @override
  Future<bool> containsKey({required String key}) async {
    try {
      return await _secureStorage.containsKey(key: key);
    } catch (e) {
      throw CacheException(message: 'Failed to check secure key: $e');
    }
  }

  // Read all values
  @override
  Future<Map<String, String>> readAll() async {
    try {
      return await _secureStorage.readAll();
    } catch (e) {
      throw CacheException(message: 'Failed to read all secure data: $e');
    }
  }
}
