abstract class AnalyticsEvent {
  String get name;

  Map<String, dynamic> get parameters => {};

  @override
  String toString() => 'AnalyticsEvent(name: $name, parameters: $parameters)';
}

class ScreenViewEvent extends AnalyticsEvent {
  final String screenName;
  final Map<String, dynamic>? screenParameters;

  ScreenViewEvent(this.screenName, {this.screenParameters});

  @override
  String get name => 'screen_view';

  @override
  Map<String, dynamic> get parameters => {
    'screen_name': screenName,
    ...?screenParameters,
  };
}

class UserActionEvent extends AnalyticsEvent {
  final String action;
  final String? category;
  final String? label;
  final int? value;
  final Map<String, dynamic>? extraParams;

  UserActionEvent({
    required this.action,
    this.category,
    this.label,
    this.value,
    this.extraParams,
  });

  @override
  String get name => 'user_action';

  @override
  Map<String, dynamic> get parameters => {
    'action': action,
    if (category != null) 'category': category,
    if (label != null) 'label': label,
    if (value != null) 'value': value,
    ...?extraParams,
  };
}

class ErrorEvent extends AnalyticsEvent {
  final String errorType;
  final String message;
  final String? stackTrace;
  final bool isFatal;

  ErrorEvent({
    required this.errorType,
    required this.message,
    this.stackTrace,
    this.isFatal = false,
  });

  @override
  String get name => 'app_error';

  @override
  Map<String, dynamic> get parameters => {
    'error_type': errorType,
    'message': message,
    'is_fatal': isFatal,
    if (stackTrace != null) 'stack_trace': stackTrace,
  };
}

class PerformanceEvent extends AnalyticsEvent {
  final String metricName;
  final num value;
  final String unit;
  final Map<String, dynamic>? extraParams;

  PerformanceEvent({
    required this.metricName,
    required this.value,
    this.unit = 'ms',
    this.extraParams,
  });

  @override
  String get name => 'performance';

  @override
  Map<String, dynamic> get parameters => {
    'metric_name': metricName,
    'value': value,
    'unit': unit,
    ...?extraParams,
  };
}
