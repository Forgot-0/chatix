import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/analytics/analytics_providers.dart';
import 'package:chatix/core/auth/biometric_service.dart';
import 'package:chatix/core/auth/debug_biometric_service.dart';
import 'package:chatix/core/auth/local_biometric_service.dart';
import 'package:chatix/core/feature_flags/feature_flag_providers.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  final useDebugService =
      kDebugMode &&
      ref.watch(
        featureFlagProvider('use_debug_biometrics', defaultValue: false),
      );

  final service = useDebugService
      ? DebugBiometricService()
      : LocalBiometricService();

  final analytics = ref.watch(analyticsProvider);

  return _AnalyticsBiometricServiceProxy(service, analytics);
});

class _AnalyticsBiometricServiceProxy implements BiometricService {
  final BiometricService _delegate;
  final Analytics _analytics;

  _AnalyticsBiometricServiceProxy(this._delegate, this._analytics);

  @override
  Future<bool> isAvailable() {
    return _delegate.isAvailable();
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() {
    return _delegate.getAvailableBiometrics();
  }

  @override
  Future<BiometricResult> authenticate({
    required String localizedReason,
    AuthReason reason = AuthReason.appAccess,
    bool sensitiveTransaction = false,
    String? dialogTitle,
    String? cancelButtonText,
  }) async {
    _analytics.logUserAction(
      action: 'biometric_auth_requested',
      category: 'authentication',
      label: reason.toString(),
      parameters: {
        'reason': reason.toString(),
        'sensitive_transaction': sensitiveTransaction,
      },
    );

    final result = await _delegate.authenticate(
      localizedReason: localizedReason,
      reason: reason,
      sensitiveTransaction: sensitiveTransaction,
      dialogTitle: dialogTitle,
      cancelButtonText: cancelButtonText,
    );

    _analytics.logUserAction(
      action: 'biometric_auth_completed',
      category: 'authentication',
      label: result.toString(),
      parameters: {'result': result.toString(), 'reason': reason.toString()},
    );

    return result;
  }
}

final biometricsAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(biometricServiceProvider);
  return await service.isAvailable();
});

final availableBiometricsProvider = FutureProvider<List<BiometricType>>((
  ref,
) async {
  final service = ref.watch(biometricServiceProvider);
  return await service.getAvailableBiometrics();
});

class BiometricAuthState {
  final bool isAuthenticated;
  final BiometricResult? lastResult;
  final DateTime? lastAuthTime;

  const BiometricAuthState({
    this.isAuthenticated = false,
    this.lastResult,
    this.lastAuthTime,
  });

  BiometricAuthState copyWith({
    bool? isAuthenticated,
    BiometricResult? lastResult,
    DateTime? lastAuthTime,
  }) {
    return BiometricAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      lastResult: lastResult ?? this.lastResult,
      lastAuthTime: lastAuthTime ?? this.lastAuthTime,
    );
  }
}

class BiometricAuthController extends Notifier<BiometricAuthState> {
  @override
  BiometricAuthState build() {
    return const BiometricAuthState();
  }

  bool get isAuthenticated => state.isAuthenticated;

  BiometricResult? get lastResult => state.lastResult;

  DateTime? get lastAuthTime => state.lastAuthTime;

  Future<BiometricResult> authenticate({
    required String reason,
    AuthReason authReason = AuthReason.appAccess,
    bool sensitiveTransaction = false,
    String? dialogTitle,
    String? cancelButtonText,
  }) async {
    final service = ref.read(biometricServiceProvider);
    final analytics = ref.read(analyticsProvider);

    final result = await service.authenticate(
      localizedReason: reason,
      reason: authReason,
      sensitiveTransaction: sensitiveTransaction,
      dialogTitle: dialogTitle,
      cancelButtonText: cancelButtonText,
    );

    BiometricAuthState newState = state.copyWith(lastResult: result);

    if (result == BiometricResult.success) {
      newState = newState.copyWith(
        isAuthenticated: true,
        lastAuthTime: DateTime.now(),
      );

      analytics.logUserAction(
        action: 'user_authenticated',
        category: 'authentication',
        label: authReason.toString(),
      );
    }

    state = newState;
    return result;
  }

  void logout() {
    final analytics = ref.read(analyticsProvider);

    state = const BiometricAuthState();

    analytics.logUserAction(
      action: 'user_logged_out',
      category: 'authentication',
    );
  }

  bool isAuthenticationNeeded({Duration? timeout}) {
    if (!state.isAuthenticated) return true;

    if (timeout != null && state.lastAuthTime != null) {
      final now = DateTime.now();
      final sessionExpiry = state.lastAuthTime!.add(timeout);
      if (now.isAfter(sessionExpiry)) {
        state = state.copyWith(isAuthenticated: false);
        return true;
      }
    }

    return false;
  }
}

final biometricAuthControllerProvider =
    NotifierProvider<BiometricAuthController, BiometricAuthState>(
      BiometricAuthController.new,
    );
