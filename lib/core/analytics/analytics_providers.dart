import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/analytics/analytics_event.dart';
import 'package:chatix/core/analytics/analytics_service.dart';
import 'package:chatix/core/analytics/firebase_analytics_service.dart';
import 'package:chatix/core/feature_flags/feature_flag_providers.dart';

class DebugAnalyticsService implements AnalyticsService {
  bool _isEnabled = true;

  @override
  Future<void> init() async {
    debugPrint('📊 Debug Analytics initialized');
  }

  @override
  void logEvent(AnalyticsEvent event) {
    if (!_isEnabled) return;
    debugPrint('📊 DEBUG ANALYTICS: ${event.name} - ${event.parameters}');
  }

  @override
  void setUserProperties({
    required String userId,
    Map<String, dynamic>? properties,
  }) {
    if (!_isEnabled) return;
    debugPrint('📊 DEBUG ANALYTICS: Set user ID: $userId');
    if (properties != null) {
      debugPrint('📊 DEBUG ANALYTICS: User properties: $properties');
    }
  }

  @override
  void resetUser() {
    if (!_isEnabled) return;
    debugPrint('📊 DEBUG ANALYTICS: Reset user');
  }

  @override
  void enable() {
    _isEnabled = true;
    debugPrint('📊 DEBUG ANALYTICS: Enabled');
  }

  @override
  void disable() {
    _isEnabled = false;
    debugPrint('📊 DEBUG ANALYTICS: Disabled');
  }

  @override
  bool get isEnabled => _isEnabled;
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final analyticsEnabled = ref.watch(
    featureFlagProvider('enable_analytics', defaultValue: true),
  );

  final services = <AnalyticsService>[];

  if (!kDebugMode ||
      ref.watch(
        featureFlagProvider('force_firebase_analytics', defaultValue: false),
      )) {
    services.add(FirebaseAnalyticsService());
  }

  if (kDebugMode) {
    services.add(DebugAnalyticsService());
  }

  final service = CompositeAnalyticsService(services);

  if (analyticsEnabled) {
    service.enable();
  } else {
    service.disable();
  }

  return service;
});

final analyticsProvider = Provider<Analytics>((ref) {
  final service = ref.watch(analyticsServiceProvider);
  return Analytics(service);
});

class Analytics {
  final AnalyticsService _service;

  Analytics(this._service);

  void logScreenView(String screenName, {Map<String, dynamic>? parameters}) {
    _service.logEvent(
      ScreenViewEvent(screenName, screenParameters: parameters),
    );
  }

  void logUserAction({
    required String action,
    String? category,
    String? label,
    int? value,
    Map<String, dynamic>? parameters,
  }) {
    _service.logEvent(
      UserActionEvent(
        action: action,
        category: category,
        label: label,
        value: value,
        extraParams: parameters,
      ),
    );
  }

  void logError({
    required String errorType,
    required String message,
    String? stackTrace,
    bool isFatal = false,
  }) {
    _service.logEvent(
      ErrorEvent(
        errorType: errorType,
        message: message,
        stackTrace: stackTrace,
        isFatal: isFatal,
      ),
    );
  }

  void logPerformance({
    required String name,
    required num value,
    String unit = 'ms',
    Map<String, dynamic>? parameters,
  }) {
    _service.logEvent(
      PerformanceEvent(
        metricName: name,
        value: value,
        unit: unit,
        extraParams: parameters,
      ),
    );
  }

  void setUser({required String userId, Map<String, dynamic>? properties}) {
    _service.setUserProperties(userId: userId, properties: properties);
  }

  void resetUser() {
    _service.resetUser();
  }

  void enable() {
    _service.enable();
  }

  void disable() {
    _service.disable();
  }

  bool get isEnabled => _service.isEnabled;
}

class AnalyticsScreenView extends StatefulWidget {
  final String screenName;
  final Map<String, dynamic>? parameters;
  final Widget child;

  const AnalyticsScreenView({
    super.key,
    required this.screenName,
    this.parameters,
    required this.child,
  });

  @override
  State<AnalyticsScreenView> createState() => _AnalyticsScreenViewState();
}

class _AnalyticsScreenViewState extends State<AnalyticsScreenView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = ProviderScope.containerOf(
        context,
      ).read(analyticsProvider);
      analytics.logScreenView(widget.screenName, parameters: widget.parameters);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
