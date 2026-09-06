import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:chatix/core/analytics/analytics_event.dart';

abstract class AnalyticsService {
  FutureOr<void> init();

  void logEvent(AnalyticsEvent event);

  void setUserProperties({
    required String userId,
    Map<String, dynamic>? properties,
  });

  void resetUser();

  void enable();

  void disable();

  bool get isEnabled;
}

class CompositeAnalyticsService implements AnalyticsService {
  final List<AnalyticsService> _services;

  CompositeAnalyticsService(this._services);

  @override
  FutureOr<void> init() async {
    for (final service in _services) {
      await service.init();
    }
  }

  @override
  void logEvent(AnalyticsEvent event) {
    for (final service in _services) {
      service.logEvent(event);
    }
  }

  @override
  void setUserProperties({
    required String userId,
    Map<String, dynamic>? properties,
  }) {
    for (final service in _services) {
      service.setUserProperties(userId: userId, properties: properties);
    }
  }

  @override
  void resetUser() {
    for (final service in _services) {
      service.resetUser();
    }
  }

  @override
  void enable() {
    for (final service in _services) {
      service.enable();
    }
  }

  @override
  void disable() {
    for (final service in _services) {
      service.disable();
    }
  }

  @override
  bool get isEnabled =>
      _services.isNotEmpty ? _services.first.isEnabled : false;
}

class DebugAnalyticsService implements AnalyticsService {
  bool _enabled = true;

  @override
  FutureOr<void> init() {
    debugPrint('🔍 DebugAnalyticsService initialized');
  }

  @override
  void logEvent(AnalyticsEvent event) {
    if (!_enabled) return;
    debugPrint('📊 Analytics Event: ${event.name}');
    debugPrint('📊 Parameters: ${event.parameters}');
  }

  @override
  void setUserProperties({
    required String userId,
    Map<String, dynamic>? properties,
  }) {
    if (!_enabled) return;
    debugPrint('👤 User identified: $userId');
    if (properties != null) {
      debugPrint('👤 User properties: $properties');
    }
  }

  @override
  void resetUser() {
    if (!_enabled) return;
    debugPrint('👤 User reset');
  }

  @override
  void enable() {
    _enabled = true;
    debugPrint('📊 Analytics enabled');
  }

  @override
  void disable() {
    _enabled = false;
    debugPrint('📊 Analytics disabled');
  }

  @override
  bool get isEnabled => _enabled;
}
