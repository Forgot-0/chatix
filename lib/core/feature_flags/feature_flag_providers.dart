import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/analytics/analytics_providers.dart';
import 'package:chatix/core/feature_flags/feature_flag_service.dart';
import 'package:chatix/core/feature_flags/local_feature_flag_service.dart';
import 'package:chatix/core/feature_flags/remote_feature_flag_service.dart';

const Map<String, dynamic> kDefaultFeatureFlags = {
  'enable_dark_mode': true,
  'enable_push_notifications': true,
  'enable_analytics': true,
  'enable_crash_reporting': true,
  'enable_biometric_login': true,
  'use_debug_biometrics': false,
  'force_firebase_analytics': false,

  'cache_ttl_seconds': 3600,
  'api_timeout_ms': 30000,
  'max_retry_count': 3,

  'home_screen_layout': 'grid',
  'onboarding_screens_count': 3,

  'primary_color': '#FF2196F3',
  'corner_radius': 8.0,
};

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  final service = kDebugMode
      ? LocalFeatureFlagService() as FeatureFlagService
      : RemoteFeatureFlagService();

  service.setDefaults(kDefaultFeatureFlags);

  service.init();

  final analytics = ref.watch(analyticsProvider);
  service.addListener(() {
    analytics.logUserAction(
      action: 'feature_flags_updated',
      category: 'config',
    );
  });

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

Provider<bool> createFeatureFlagProvider(
  String flagKey, {
  bool defaultValue = false,
}) {
  return Provider<bool>((ref) {
    final service = ref.watch(featureFlagServiceProvider);
    return service.getBool(flagKey, defaultValue: defaultValue);
  });
}

Provider<bool> featureFlagProvider(
  String flagKey, {
  bool defaultValue = false,
}) {
  return Provider<bool>((ref) {
    final service = ref.watch(featureFlagServiceProvider);
    return service.getBool(flagKey, defaultValue: defaultValue);
  });
}

Provider<String> stringConfigProvider(
  String key, {
  required String defaultValue,
}) {
  return Provider<String>((ref) {
    final service = ref.watch(featureFlagServiceProvider);
    return service.getString(key, defaultValue: defaultValue);
  });
}

Provider<int> intConfigProvider(String key, {required int defaultValue}) {
  return Provider<int>((ref) {
    final service = ref.watch(featureFlagServiceProvider);
    return service.getInt(key, defaultValue: defaultValue);
  });
}

Provider<double> doubleConfigProvider(
  String key, {
  required double defaultValue,
}) {
  return Provider<double>((ref) {
    final service = ref.watch(featureFlagServiceProvider);
    return service.getDouble(key, defaultValue: defaultValue);
  });
}

Provider<Color> colorConfigProvider(String key, {required Color defaultValue}) {
  return Provider<Color>((ref) {
    final service = ref.watch(featureFlagServiceProvider);
    return service.getColor(key, defaultValue: defaultValue);
  });
}

class FeatureFlag extends ConsumerWidget {
  final String featureKey;
  final bool defaultValue;
  final Widget child;
  final Widget? fallback;

  const FeatureFlag({
    super.key,
    required this.featureKey,
    this.defaultValue = false,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(featureFlagServiceProvider);
    final enabled = service.getBool(featureKey, defaultValue: defaultValue);

    if (enabled) {
      return child;
    } else {
      return fallback ?? const SizedBox.shrink();
    }
  }
}
