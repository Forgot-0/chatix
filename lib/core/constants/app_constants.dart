import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static String get serverBaseUrl {
    final raw = dotenv.env['BASE_URL']?.trim();
    if (raw == null || raw.isEmpty) {
      return 'https://api.yourdomain.com';
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  static String get apiBaseUrl => '$serverBaseUrl/api/v1';

  static String get healthCheckUrl => '$serverBaseUrl/health';

  static const String accessTokenKey = 'access_token';
  static const String userDataKey = 'userData';

  static const String appName = 'ChatiX';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.forgot.chatix';
  static const String iOSAppId = '123456789';
  static const String appcastUrl = 'https://your-appcast-url.com/appcast.xml';

  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';
  static const String offlineSyncBox = 'offlineSync';

  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  static const Duration accessibilityTooltipDuration = Duration(seconds: 5);
  static const double accessibilityTouchTargetMinSize = 48.0;

  static const int minSessionsBeforeReview = 5;
  static const int minDaysBeforeReview = 7;
  static const int minActionsBeforeReview = 10;
}
