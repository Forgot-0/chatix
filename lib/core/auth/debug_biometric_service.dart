import 'package:flutter/foundation.dart';
import 'package:chatix/core/auth/biometric_service.dart';

class DebugBiometricService implements BiometricService {
  final bool _isAvailable;
  final List<BiometricType> _availableBiometrics;

  DebugBiometricService({
    bool isAvailable = true,
    List<BiometricType>? availableBiometrics,
  }) : _isAvailable = isAvailable,
       _availableBiometrics =
           availableBiometrics ??
           (isAvailable ? [BiometricType.fingerprint] : []);

  @override
  Future<bool> isAvailable() async {
    debugPrint('👆 Checking biometrics availability: $_isAvailable');
    await Future.delayed(const Duration(milliseconds: 500));
    return _isAvailable;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    debugPrint('👆 Getting available biometrics: $_availableBiometrics');
    await Future.delayed(const Duration(milliseconds: 500));
    return _availableBiometrics;
  }

  @override
  Future<BiometricResult> authenticate({
    required String localizedReason,
    AuthReason reason = AuthReason.appAccess,
    bool sensitiveTransaction = false,
    String? dialogTitle,
    String? cancelButtonText,
  }) async {
    debugPrint('👆 Authenticating with biometrics');
    debugPrint('👆 Reason: $localizedReason');
    debugPrint('👆 Auth reason: $reason');
    debugPrint('👆 Sensitive: $sensitiveTransaction');

    if (!_isAvailable) {
      debugPrint('👆 Result: notAvailable');
      return BiometricResult.notAvailable;
    }

    if (_availableBiometrics.isEmpty) {
      debugPrint('👆 Result: notEnrolled');
      return BiometricResult.notEnrolled;
    }

    await Future.delayed(const Duration(seconds: 1));

    debugPrint('👆 Result: success');
    return BiometricResult.success;
  }
}
