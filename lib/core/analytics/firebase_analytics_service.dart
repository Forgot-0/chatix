import 'package:flutter/foundation.dart';
import 'package:chatix/core/analytics/analytics_event.dart';
import 'package:chatix/core/analytics/analytics_service.dart';

/// Implementation of AnalyticsService using Firebase Analytics
/// Note: In a real app, you would include the firebase_analytics package
/// and use the actual Firebase implementation
class FirebaseAnalyticsService implements AnalyticsService {
  bool _isEnabled = true;

  /// Mock Firebase Analytics instance
  /// In a real app, this would be a FirebaseAnalytics instance
  final Map<String, dynamic> _userProperties = {};

  @override
  Future<void> init() async {
    debugPrint('📊 Firebase Analytics initialized');
    _isEnabled = true;
  }

  @override
  void logEvent(AnalyticsEvent event) {
    if (!_isEnabled) return;

    final eventName = event.name.replaceAll(' ', '_');
    final params = event.parameters;

    // Log different event types
    if (event is ScreenViewEvent) {
      debugPrint(
        '📊 Firebase screen view: ${event.screenName}, params: $params',
      );
    } else if (event is UserActionEvent) {
      debugPrint('📊 Firebase user action: ${event.action}, params: $params');
    } else if (event is ErrorEvent) {
      debugPrint(
        '📊 Firebase error: ${event.errorType}, message: ${event.message}, params: $params',
      );
    } else if (event is PerformanceEvent) {
      debugPrint(
        '📊 Firebase performance: ${event.metricName}, value: ${event.value}${event.unit}, params: $params',
      );
    } else {
      // Generic event
      debugPrint('📊 Firebase log event: $eventName, params: $params');
    }
  }

  @override
  void setUserProperties({
    required String userId,
    Map<String, dynamic>? properties,
  }) {
    if (!_isEnabled) return;

    debugPrint('📊 Firebase set user ID: $userId');

    _userProperties['user_id'] = userId;

    if (properties != null) {
      properties.forEach((key, value) {
        _userProperties[key] = value;
        debugPrint('📊 Firebase set user property: $key = $value');
      });
    }
  }

  @override
  void resetUser() {
    if (!_isEnabled) return;

    debugPrint('📊 Firebase reset user');
    _userProperties.clear();
  }

  @override
  void enable() {
    _isEnabled = true;
    debugPrint('📊 Firebase Analytics enabled');
  }

  @override
  void disable() {
    _isEnabled = false;
    debugPrint('📊 Firebase Analytics disabled');
  }

  @override
  bool get isEnabled => _isEnabled;
}
