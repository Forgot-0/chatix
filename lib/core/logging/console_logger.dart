import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:chatix/core/logging/logger.dart';

class ConsoleLogger implements Logger {
  final String _tag;

  LogLevel _logLevel;

  final bool _includeTimestamp;

  final bool _includeLogLevel;

  final DateFormat _timestampFormat;

  ConsoleLogger({
    String tag = '',
    LogLevel logLevel = LogLevel.info,
    bool includeTimestamp = true,
    bool includeLogLevel = true,
  }) : _tag = tag,
       _logLevel = logLevel,
       _includeTimestamp = includeTimestamp,
       _includeLogLevel = includeLogLevel,
       _timestampFormat = DateFormat('HH:mm:ss.SSS');

  @override
  void v(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.verbose,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void d(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.debug,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void i(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.info,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void w(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.warning,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void e(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.error,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void c(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.critical,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void p(String message, {Map<String, dynamic>? data, Duration? duration}) {
    final perfData = <String, dynamic>{...?data};
    if (duration != null) {
      perfData['duration_ms'] = duration.inMicroseconds / 1000;
    }
    log(LogLevel.performance, message, data: perfData);
  }

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _logLevel.index) return;

    final buffer = StringBuffer();

    if (_includeTimestamp) {
      final timestamp = _timestampFormat.format(DateTime.now());
      buffer.write('[$timestamp] ');
    }

    if (_includeLogLevel) {
      final levelStr = _getLevelString(level);
      buffer.write('$levelStr ');
    }

    if (_tag.isNotEmpty) {
      buffer.write('[$_tag] ');
    }

    buffer.write(message);

    if (data != null && data.isNotEmpty) {
      buffer.write(' - ${_formatData(data)}');
    }

    debugPrint(buffer.toString());

    if (error != null) {
      debugPrint('Error: $error');
      final trace = stackTrace ?? StackTrace.current;
      debugPrint('Stack trace:\n$trace');
    }
  }

  @override
  void setLogLevel(LogLevel level) {
    _logLevel = level;
  }

  @override
  LogLevel getLogLevel() {
    return _logLevel;
  }

  @override
  Logger child(String tag) {
    final newTag = _tag.isEmpty ? tag : '$_tag:$tag';
    return ConsoleLogger(
      tag: newTag,
      logLevel: _logLevel,
      includeTimestamp: _includeTimestamp,
      includeLogLevel: _includeLogLevel,
    );
  }

  String _getLevelString(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return '[VERB]';
      case LogLevel.debug:
        return '[DEBUG]';
      case LogLevel.info:
        return '[INFO]';
      case LogLevel.warning:
        return '[WARN]';
      case LogLevel.error:
        return '[ERROR]';
      case LogLevel.critical:
        return '[CRIT]';
      case LogLevel.performance:
        return '[PERF]';
    }
  }

  String _formatData(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }
}
