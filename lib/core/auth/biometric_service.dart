enum BiometricResult {
  success,

  failed,

  cancelled,

  notEnrolled,

  notAvailable,

  lockedOut,

  error,
}

enum BiometricType {
  fingerprint,

  face,

  iris,

  multiple,
}

enum AuthReason {
  appAccess,

  transaction,

  sensitiveData,
}

abstract class BiometricService {
  Future<bool> isAvailable();

  Future<List<BiometricType>> getAvailableBiometrics();

  Future<BiometricResult> authenticate({
    required String localizedReason,
    AuthReason reason = AuthReason.appAccess,
    bool sensitiveTransaction = false,
    String? dialogTitle,
    String? cancelButtonText,
  });
}
