import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  /// Backend origin without trailing slash (from `.env` BASE_URL).
  static String get serverBaseUrl {
    final raw = dotenv.env['BASE_URL']?.trim();
    if (raw == null || raw.isEmpty) {
      return 'https://api.yourdomain.com';
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// API v1 prefix for all versioned endpoints (api-docs §1.1).
  static String get apiBaseUrl => '$serverBaseUrl/api/v1';

  /// Health check lives outside `/api/v1` (api-docs §1.1).
  static String get healthCheckUrl => '$serverBaseUrl/health';

  // Storage constants
  static const String accessTokenKey = 'access_token';
  static const String userDataKey = 'userData';

  // App constants
  static const String appName = 'ChatiX';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.forgot.chatix';
  static const String iOSAppId = '123456789';
  static const String appcastUrl = 'https://your-appcast-url.com/appcast.xml';

  // Timeout durations
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Route constants
  static const String initialRoute = '/';
  static const String homeRoute = '/home';
  static const String chatRoute = '/chat';
  static const String surveyRoute = '/survey';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String verifyEmailRoute = '/verify-email';
  static const String resetPasswordRequestRoute = '/reset-password';
  static const String resetPasswordConfirmRoute = '/reset-password/confirm';
  static const String profileRoute = '/profile';
  static const String profileEditRoute = '/profile/edit';
  static const String profilesListRoute = '/profiles';

  /// `/profile/{id}` — viewing someone else's profile. Kept as a helper
  /// rather than another constant since it needs the id interpolated;
  /// mirrors the [profileRoute] ("my own profile", no id) vs. this ("a
  /// specific profile") split in `app_router.dart`.
  static String profileDetailRoute(int profileId) => '/profile/$profileId';
  static const String settingsRoute = '/settings';
  static const String languageSettingsRoute = '/settings/language';
  static const String localizationDemoRoute = '/demo/localization';
  static const String localizationAssetsDemoRoute = '/demo/localization/assets';

  // Hive box names
  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';
  static const String offlineSyncBox = 'offlineSync';

  // Animation durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  // Accessibility
  static const Duration accessibilityTooltipDuration = Duration(seconds: 5);
  static const double accessibilityTouchTargetMinSize = 48.0;

  // App Review
  static const int minSessionsBeforeReview = 5;
  static const int minDaysBeforeReview = 7;
  static const int minActionsBeforeReview = 10;
}
