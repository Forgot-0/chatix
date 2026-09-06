import 'package:chatix/core/storage/secure_storage_service.dart';

class FakeSecureStorageService implements SecureStorageService {
  FakeSecureStorageService({Map<String, String>? initialValues})
    : _values = {...?initialValues};

  final Map<String, String> _values;

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }

  @override
  Future<bool> containsKey({required String key}) async =>
      _values.containsKey(key);

  @override
  Future<Map<String, String>> readAll() async => Map.unmodifiable(_values);
}
